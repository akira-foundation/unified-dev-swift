import Foundation

extension WorkspaceStartTool {
    enum WatchOutcome: Equatable {
        case notRequested
        case watching
        case noChat
        case failed(String)
    }

    func watch(
        _ started: StartedWorkspaceSummary, for request: MCPRequest, from identity: BridgeIdentity, store: Store
    ) async -> WatchOutcome {
        guard WorkspaceDoneWatch.isRequested(request.param(WorkspaceDoneWatch.argument)) else { return .notRequested }
        guard let watcher = identity.sessionID, identity.workspaceID != nil else { return .noChat }
        do {
            try await store.watchFirstTurn(of: started, for: watcher)
            return .watching
        } catch {
            return .failed(error.readableMessage)
        }
    }

    func startedAnswer(_ started: StartedWorkspaceSummary, role: BridgeRole, watch: WatchOutcome) -> JSONValue {
        .object([
            "workspace_id": .string(started.workspaceID.rawValue),
            "name": .string(started.name),
            "branch": .string(started.branch),
            "path": .string(started.path),
            "state": .string("starting"),
            WorkspaceDoneWatch.argument: .bool(watch == .watching),
            "note": .string(startedNote(for: role, watch: watch)),
        ])
    }

    func startedNote(for role: BridgeRole, watch: WatchOutcome) -> String {
        let opening = watch == .watching
            ? "It is setting up and will start on its own. Unified Dev will tell this chat once, by "
                + "itself, when its first turn comes to rest: finished, failed, or waiting on the "
                + "owner. You cannot wait for it from here, so carry on with your own work."
            : "It is setting up and will start on its own. It does not report back, and "
                + "you cannot wait for it from here. Carry on with your own work."
        let ownerLine = role == .owner ? " When you want to know what became of it, call workspace_list." : ""
        return opening + ownerLine + watchLine(watch)
    }

    private func watchLine(_ watch: WatchOutcome) -> String {
        switch watch {
        case .notRequested, .watching:
            ""
        case .noChat:
            " notify_when_done was ignored: this connection is not a chat in a Unified Dev "
                + "workspace, so there is nowhere to deliver the notice."
        case .failed(let reason):
            " Unified Dev could not record notify_when_done, so it will not tell you when the new "
                + "agent is done: \(reason)"
        }
    }
}
