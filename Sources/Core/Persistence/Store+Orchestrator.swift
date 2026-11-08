import Foundation

extension Store {
    @discardableResult
    public func setOrchestrator(
        _ isOrchestrator: Bool, workspaceID: WorkspaceID, hasLiveWork: Bool = false
    ) throws -> Workspace? {
        guard let row = try workspace(id: workspaceID) else { return nil }
        guard row.isOrchestrator != isOrchestrator else { return row }
        if isOrchestrator {
            let neighbours = try workspaces(repoID: row.repoID, includeArchived: true)
            if case .refused(let sentence) = OrchestratorRole.assignment(of: row, among: neighbours) {
                throw WorkspaceError.orchestratorRefused(sentence)
            }
            if try hasLiveWork || sessions(workspaceID: workspaceID).contains(where: \.state.isMidTurn) {
                throw WorkspaceError.orchestratorHasLiveWork
            }
        }
        return try update(workspaceID: workspaceID) { $0.isOrchestrator = isOrchestrator }
    }

    public func orchestratesAtLaunch(workspaceID: WorkspaceID) -> Bool {
        do {
            return try workspace(id: workspaceID)?.isOrchestrator ?? false
        } catch {
            return true
        }
    }

    @concurrent public nonisolated func orchestratorHandover(
        from workspaceID: WorkspaceID, terminalAgents: [AgentKind] = []
    ) async throws -> String? {
        guard let origin = try await workspace(id: workspaceID) else { return nil }
        let chats = try await sessions(workspaceID: workspaceID)
        let limit = OrchestratorHandover.readChatLimit
        let budget = ConversationHandoff.defaultBudget / max(min(chats.count, limit), 1)
        var conversations: [SessionID: String] = [:]
        for chat in OrchestratorHandover.chatsInReadingOrder(chats) where conversations.count < limit {
            let rows = try await handoffRows(sessionID: chat.id, afterSeq: -1, excludingSeq: nil)
            conversations[chat.id] = ConversationHandoff.text(
                messages: rows, worktree: nil, chatID: chat.id, budget: budget, agent: chat.agentKind
            )
        }
        let worktree = await HandoffWorktree.read(path: origin.path, base: origin.baseBranch)
        return OrchestratorHandover.prompt(
            from: origin, sessions: chats, conversations: conversations, worktree: worktree, terminalAgents: terminalAgents
        )
    }
}
