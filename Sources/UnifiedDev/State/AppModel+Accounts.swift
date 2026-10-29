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

struct ComposerAccountHomes: Hashable {
    var claude: AgentAccountHome?
    var codex: AgentAccountHome?
}

struct ComposerAccountKey: Hashable {
    var fingerprint: AccountFingerprint
    var provider: AgentKind
}

struct ComposerAccountReading: Equatable {
    var key: ComposerAccountKey
    var line: AgentAccountLine
    var homes: ComposerAccountHomes
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

    func composerAccountKey(for scope: AccountScope, provider: AgentKind) -> ComposerAccountKey {
        ComposerAccountKey(fingerprint: accountFingerprint(for: scope), provider: provider)
    }

    func composerAccounts(for key: ComposerAccountKey) async -> ComposerAccountReading? {
        guard let resolution = await accountResolution(for: key.fingerprint.scope) else { return nil }
        return ComposerAccountReading(
            key: key,
            line: resolution.line(for: key.provider),
            homes: ComposerAccountHomes(claude: resolution.home(for: .claudeCode), codex: resolution.home(for: .codex))
        )
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
            workspace: fingerprint.workspace,
            project: fingerprint.project,
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

extension AppModel {
    func noteSwitched(to account: AgentAccountID) {
        lastSwitchedAccount = account
    }

    func noteAccountSignedOut(_ account: AgentAccountID) {
        let cause = AgentAccountSignOut.cause(afterSwitchingTo: lastSwitchedAccount, failedOn: account)
        guard signedOutAccounts[account] != cause else { return }
        signedOutAccounts[account] = cause
    }

    func noteAccountWorking(_ account: AgentAccountID) {
        guard signedOutAccounts[account] != nil else { return }
        signedOutAccounts[account] = nil
    }

    func quotaAccountOffers(at now: Date) -> [AgentKind: QuotaAccountOffer] {
        guard let workspace = selectedWorkspace,
              let transcript = existingModel(for: workspace.id)?.activeTranscript,
              let current = selectedAccountHomes[transcript.session.agentKind]
        else { return [:] }
        let session = transcript.session
        let offer = QuotaAccountOffer.make(QuotaAccountOffer.Input(
            session: session,
            current: current,
            standings: agentAccounts.standings,
            notices: MenuBarPanelContent.limitNotices(quotas, at: now),
            signedOut: signedOutAccounts[current.id],
            isTurnInFlight: transcript.isRunning,
            workspaceName: workspace.name,
            now: now
        ))
        return offer.map { [session.agentKind: $0] } ?? [:]
    }

    func restartTurn(on account: AgentAccountHome) async {
        guard let workspace = selectedWorkspace,
              let transcript = existingModel(for: workspace.id)?.activeTranscript,
              transcript.session.agentKind == account.provider
        else { return }
        if let complaint = await transcript.restartTurn(on: account) {
            notice = Notice(message: complaint, tone: .error)
        }
        await adoptSelectedAccounts()
    }
}
