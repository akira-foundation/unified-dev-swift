import Foundation

extension Store {
    public func announceToOrchestrator(_ started: Workspace, prompt: String, firstChat: Session?) throws -> Session? {
        guard let orchestrator = OrchestratorRole.announcedOrchestrator(
            for: started, among: try workspaces(repoID: started.repoID)
        ),
            let chat = try sessions(workspaceID: orchestrator.id).first(where: { $0.parentSessionID == nil })
        else { return nil }

        let hasTask = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let watched = hasTask ? firstChat : nil
        if let watched {
            try addWorkspaceDoneWatch(WorkspaceDoneWatch(
                cause: .start,
                watcherSessionID: chat.id,
                target: WorkspaceMessageEnd(
                    workspaceID: started.id, workspace: started.name, sessionID: watched.id, chat: watched.title
                )
            ))
        }

        let parentName = try started.origin.parentWorkspaceID.flatMap { try workspace(id: $0) }?.name
        try enqueueDelivery(Delivery(
            targetSessionID: chat.id,
            sourceWorkspaceID: started.id,
            kind: .report,
            crew: WorkspaceStartedNotice.message(
                for: started,
                startedBy: WorkspaceStartedNotice.startedBy(started.origin, parentName: parentName),
                watchesFirstTurn: watched != nil,
                prompt: prompt
            )
        ))
        return chat
    }
}
