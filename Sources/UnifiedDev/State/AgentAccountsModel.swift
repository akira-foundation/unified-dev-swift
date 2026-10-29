import Foundation
import Observation
import Core

@MainActor
@Observable
final class AgentAccountsModel {
    struct Creation: Identifiable {
        let id = UUID()
        let plan: AgentAccountCreation
        let directoryExistedBefore: Bool
    }

    enum Activity: Equatable {
        case idle
        case checkingSessions
        case confirmingSignIn
    }

    private(set) var standings: [AgentAccountStanding] = []
    private(set) var orphans: [AgentAccountHome] = []
    private(set) var codexStorageMode: CodexAuthStorageMode = .file
    private(set) var activity = Activity.idle
    private(set) var failure: String?

    @ObservationIgnored private var lastAskedAt: Date?
    @ObservationIgnored private var answers: [AgentAccountID: AgentAccountLiveness.CliReport] = [:]
    @ObservationIgnored private var creatingDirectory: URL?

    func panel(for provider: AgentKind) -> AgentAccountPanel {
        AgentAccountPanel.make(
            provider: provider, standings: standings, orphans: orphans, codexStorageMode: codexStorageMode
        )
    }

    func dismissFailure() {
        failure = nil
    }

    func reload(store: Store?) async {
        guard let store else { return }
        do {
            let rows = try await store.agentAccounts()
            let defaults = SpendAccounts.defaultHomes()
            let plain = await AgentAccountInventory.standingsWithoutAsking(rows: rows, defaults: defaults)
            adopt(plain.map { $0.reporting(answers) }, rows: rows, defaults: defaults, store: store)
        } catch {
            failure = "Could not read the accounts: \(error.readableMessage)"
        }
    }

    func askIfDue(after gap: TimeInterval, executables: [AgentKind: String], store: Store?) async {
        guard let store, activity == .idle,
              QuotaPollSchedule.isDue(lastAskedAt: lastAskedAt, at: Date(), after: gap)
        else { return }
        activity = .checkingSessions
        let previous = lastAskedAt
        lastAskedAt = Date()
        defer { activity = .idle }
        let defaults = SpendAccounts.defaultHomes()
        let liveness = AgentAccountLiveness.using(executables: executables)
        guard let rows = try? await store.agentAccounts(),
              let asked = await AgentAccountInventory.standingsUnlessCancelled(rows: rows, defaults: defaults, report: {
                  await liveness.report(for: $0)
              })
        else {
            lastAskedAt = previous
            return
        }
        answers = Dictionary(asked.map { ($0.home.id, $0.cliReport) }, uniquingKeysWith: { _, latest in latest })
        adopt(asked, rows: rows, defaults: defaults, store: store)
    }

    func beginCreation(provider: AgentKind, label: String, store: Store?) async -> Creation? {
        guard let store, let clean = AgentAccountCreation.cleanLabel(label) else { return nil }
        let support = Self.support(of: store)
        do {
            let existing = try await store.agentAccounts().map(\.id)
            let plan = AgentAccountCreation.plan(
                provider: provider,
                label: clean,
                existing: existing + AgentAccountCreation.occupiedIDs(support: support),
                support: support
            )
            failure = nil
            creatingDirectory = plan.directory
            return Creation(plan: plan, directoryExistedBefore: plan.directoryExists)
        } catch {
            failure = "Could not read the accounts: \(error.readableMessage)"
            return nil
        }
    }

    func finishCreation(
        _ creation: Creation,
        exit: TerminalExit?,
        executables: [AgentKind: String],
        store: Store?
    ) async {
        let plan = creation.plan
        creatingDirectory = nil
        if exit == .exited(0) { activity = .confirmingSignIn }
        defer { activity = .idle }
        let liveness = AgentAccountLiveness.using(executables: executables)
        guard let standing = await AgentAccountInventory.concluding(plan, exit: exit, report: {
            await liveness.report(for: $0)
        }) else {
            plan.discardUnusedDirectory(existedBefore: creation.directoryExistedBefore)
            failure = "The sign-in for \(plan.label) did not complete, so no account was added."
            await reload(store: store)
            return
        }
        guard let store else {
            failure = "\(plan.label) is signed in but could not be saved, because the database is not open."
            return
        }
        do {
            try await store.add(AgentAccountRow(
                id: plan.id, provider: plan.provider, directory: plan.directory.path, label: plan.label
            ))
        } catch {
            failure = "\(plan.label) is signed in but could not be saved: \(error.readableMessage)"
            await reload(store: store)
            return
        }
        answers[plan.id] = standing.cliReport
        failure = nil
        await reload(store: store)
    }

    func remove(_ row: AgentAccountPanel.Row, store: Store?) async {
        guard let store else { return }
        let support = Self.support(of: store)
        do {
            if row.isUnfinished {
                try AgentAccountRemoval.removeUnfinished(row.home, support: support)
            } else {
                try await AgentAccountRemoval.remove(row.home, support: support, store: store)
                answers[row.id] = nil
            }
            failure = nil
        } catch {
            failure = "Could not remove \(row.title): \(error.readableMessage)"
        }
        await reload(store: store)
    }

    private func adopt(
        _ latest: [AgentAccountStanding],
        rows: [AgentAccountRow],
        defaults: [AgentAccountHome],
        store: Store
    ) {
        if standings != latest { standings = latest }
        let found = AgentAccountOrphans.find(
            support: Self.support(of: store), rows: rows, defaults: defaults,
            excluding: creatingDirectory.map { [$0] } ?? []
        )
        if orphans != found { orphans = found }
        let mode = AgentAccountInventory.codexStorageMode(among: defaults)
        if codexStorageMode != mode { codexStorageMode = mode }
    }

    private static func support(of store: Store) -> URL {
        URL(filePath: store.path).deletingLastPathComponent()
    }
}
