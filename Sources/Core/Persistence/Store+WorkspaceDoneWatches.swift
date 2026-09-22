import Foundation

extension Store {
    public func watchFirstTurn(of started: StartedWorkspaceSummary, for watcher: SessionID) throws {
        let chat = try sessions(workspaceID: started.workspaceID).first { $0.parentSessionID == nil }
        try addWorkspaceDoneWatch(WorkspaceDoneWatch(
            cause: .start,
            watcherSessionID: watcher,
            target: WorkspaceMessageEnd(
                workspaceID: started.workspaceID,
                workspace: started.name,
                sessionID: chat?.id,
                chat: chat?.title ?? ""
            )
        ))
    }
}
