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

    public func settleWorkspaceDoneWatches(
        on workspaceID: WorkspaceID,
        ending: WorkspaceTurnEnding,
        in sessionID: SessionID?,
        isSubagentChat: Bool,
        at date: Date = Date()
    ) throws -> [Session] {
        var told: [Session] = []
        for watch in try unspentWorkspaceDoneWatches(targetWorkspaceID: workspaceID) {
            switch watch.verdict(on: ending, in: sessionID, isSubagentChat: isSubagentChat) {
            case .ignore:
                continue
            case .discard:
                try claimWorkspaceDoneWatch(id: watch.id, at: date)
            case .notify(let notice):
                guard try claimWorkspaceDoneWatch(id: watch.id, at: date),
                      let chat = try liveWatcher(watch.watcherSessionID)
                else { continue }
                try enqueueDelivery(Delivery(
                    targetSessionID: chat.id, sourceWorkspaceID: workspaceID, kind: .report, crew: notice
                ))
                told.append(chat)
            }
        }
        return told
    }

    private func liveWatcher(_ id: SessionID) throws -> Session? {
        guard let chat = try session(id: id), chat.archivedAt == nil,
              let workspaceID = chat.workspaceID,
              let workspace = try workspace(id: workspaceID), workspace.state != .archived
        else { return nil }
        return chat
    }
}
