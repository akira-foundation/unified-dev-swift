import Foundation
import Core

struct AccountScope: Hashable, Sendable {
    var workspaceID: WorkspaceID?
    var repoID: RepoID?

    static let none = AccountScope()
}

struct AccountFingerprint: Hashable, Sendable {
    var scope: AccountScope
    var workspace: AgentAccountID?
    var project: AgentAccountID?
}

struct ComposerAccountReading: Equatable {
    var line: AgentAccountLine
    var codexHome: AgentAccountHome?
}

extension AppModel {
    var selectedAccountScope: AccountScope {
        guard let workspace = selectedWorkspace else { return .none }
        return AccountScope(workspaceID: workspace.id, repoID: workspace.repoID)
    }

    func accountFingerprint(for scope: AccountScope) -> AccountFingerprint {
        let workspace = scope.workspaceID.flatMap { id in workspaces.first { $0.id == id } }
        let repoID = scope.repoID ?? workspace?.repoID
        let repo = repoID.flatMap { id in repos.first { $0.id == id } }
        return AccountFingerprint(scope: scope, workspace: workspace?.accountID, project: repo?.accountID)
    }

    func accountResolution(for scope: AccountScope) async -> AgentAccountResolution? {
        guard let store else { return nil }
        return try? await AgentAccountResolver.resolve(
            workspaceID: scope.workspaceID, repoID: scope.repoID, store: store
        )
    }

    func composerAccounts(scope: AccountScope, provider: AgentKind) async -> ComposerAccountReading? {
        guard let resolution = await accountResolution(for: scope) else { return nil }
        return ComposerAccountReading(line: resolution.line(for: provider), codexHome: resolution.home(for: .codex))
    }

    func account(for provider: AgentKind, in scope: AccountScope) async throws -> AgentAccountHome? {
        guard let store else { return nil }
        return try await AgentAccountResolver.resolve(
            workspaceID: scope.workspaceID, repoID: scope.repoID, store: store
        ).home(for: provider)
    }

    func accountOptions(level: AgentAccountOptions.Scope, in scope: AccountScope) async -> AgentAccountOptions? {
        guard let resolution = await accountResolution(for: scope) else { return nil }
        let fingerprint = accountFingerprint(for: scope)
        return AgentAccountOptions.make(
            scope: level,
            stored: level == .project ? fingerprint.project : fingerprint.workspace,
            inherited: fingerprint.project,
            standings: resolution.standings
        )
    }

    func chooseAccount(
        _ home: AgentAccountHome?,
        level: AgentAccountOptions.Scope,
        in scope: AccountScope
    ) async -> String? {
        guard let store else { return "Unified Dev has no database open." }
        do {
            switch level {
            case .project:
                guard let repoID = scope.repoID else { return "This project is not known." }
                try await AgentAccountAssignment.choose(home, forRepo: repoID, in: store)
            case .workspace:
                guard let workspaceID = scope.workspaceID else { return "This workspace is not known." }
                try await AgentAccountAssignment.choose(home, forWorkspace: workspaceID, in: store)
            }
            return nil
        } catch {
            return "Could not save the account: \(error.readableMessage)"
        }
    }

    func adoptSelectedAccounts() async {
        guard let store else { return }
        let fingerprint = accountFingerprint(for: selectedAccountScope)
        guard fingerprint != accountSyncKey else { return }
        accountSyncKey = fingerprint
        guard let resolution = await accountResolution(for: fingerprint.scope) else {
            accountSyncKey = nil
            return
        }
        let previous = selectedAccountHomes
        selectedAccountHomes = resolution.homes
        ComposerModelCatalog.shared.adopt(accounts: resolution.homes, store: store)
        guard !previous.isEmpty, previous != resolution.homes else { return }
        await refreshQuotas(after: 0)
    }
}
