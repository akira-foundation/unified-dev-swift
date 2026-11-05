import Foundation
import Core

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
        AccountFingerprint.make(
            scope: scope,
            book: accountChoices,
            repoID: scope.workspaceID.flatMap { id in workspaces.first { $0.id == id } }?.repoID
        )
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

    func accounts(in scope: AccountScope) async throws -> AgentAccountResolution? {
        guard let store else { return nil }
        return try await AgentAccountResolver.resolve(
            workspaceID: scope.workspaceID, repoID: scope.repoID, store: store
        )
    }

    func account(for provider: AgentKind, in scope: AccountScope) async throws -> AgentAccountHome? {
        try await accounts(in: scope)?.home(for: provider)
    }

    func accountOptions(level: AgentAccountOptions.Scope, in scope: AccountScope) async -> AgentAccountOptions? {
        await accountResolution(for: scope)?.options(level)
    }

    func chooseAccount(
        _ chosen: ChosenAgentAccount,
        level: AgentAccountOptions.Scope,
        in scope: AccountScope
    ) async -> String? {
        guard let store else { return AgentAccountAssignment.noDatabase }
        do {
            switch AgentAccountAssignment.target(level, repoID: scope.repoID, workspaceID: scope.workspaceID) {
            case .failure(let unknown):
                return unknown.sentence
            case .success(.repo(let repoID)):
                try await AgentAccountAssignment.choose(chosen, forRepo: repoID, in: store)
            case .success(.workspace(let workspaceID)):
                try await AgentAccountAssignment.choose(chosen, forWorkspace: workspaceID, in: store)
            }
            accountMarks.noteChosen()
            return nil
        } catch {
            return AgentAccountAssignment.saveFailure(error.readableMessage)
        }
    }

    func adoptSelectedAccounts() async {
        guard let store else { return }
        let fingerprint = accountFingerprint(for: selectedAccountScope)
        guard fingerprint != accountSyncKey else { return }
        accountSyncKey = fingerprint
        guard let resolution = await accountResolution(for: fingerprint.scope) else {
            if accountSyncKey == fingerprint { accountSyncKey = nil }
            return
        }
        guard accountFingerprint(for: selectedAccountScope) == fingerprint else { return }
        let previous = selectedAccountHomes
        selectedAccountHomes = resolution.homes
        ComposerModelCatalog.shared.adopt(accounts: resolution.homes, store: store)
        guard !previous.isEmpty, previous != resolution.homes else { return }
        await refreshQuotas(after: 0)
    }
}

extension AppModel {
    func noteSwitched(to account: AgentAccountID) {
        accountMarks.noteSwitched(to: account, at: Date())
    }

    func observeAccount(_ observation: AgentAccountSignOut.Observation, on account: AgentAccountID) {
        var marks = accountMarks
        marks.apply(observation, on: account, at: Date())
        guard marks != accountMarks else { return }
        accountMarks = marks
    }

    func quotaAccountOffers(at now: Date) -> [AgentKind: QuotaAccountOffer] {
        guard let workspace = selectedWorkspace,
              let transcript = existingModel(for: workspace.id)?.activeTranscript,
              let current = selectedAccountHomes[transcript.session.agentKind]
        else { return [:] }
        let session = transcript.session
        let notices = MenuBarPanelContent.limitNotices(quotas, at: now)
        let signedOut = accountMarks.cause(for: current.id)
        let offer = QuotaAccountOffer.make(QuotaAccountOffer.Input(
            session: session,
            current: current,
            standings: agentAccounts.standings,
            notices: notices,
            signedOut: signedOut,
            isTurnInFlight: transcript.isRunning,
            lastTurnEndedCleanly: QuotaAccountOffer.readsLastTurn(
                provider: session.agentKind, notices: notices, signedOut: signedOut, isTurnInFlight: transcript.isRunning
            ) && transcript.lastTurnEndedCleanly,
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
        let asksForResume = quotaAccountOffers(at: Date())[account.provider]?.resumesTask == true
        if let complaint = await transcript.restartTurn(
            on: account, resume: asksForResume ? .quotaAccount : .accountOnly
        ) {
            notice = Notice(message: complaint, tone: .error)
        }
        await adoptSelectedAccounts()
    }
}
