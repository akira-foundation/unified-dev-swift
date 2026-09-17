import Foundation

public enum WorkspaceArchiveSafety {
    public static func objection(
        to workspace: Workspace,
        excusing asking: SessionID?,
        store: Store
    ) async -> String? {
        if workspace.setupState == .running {
            return "Workspace setup is still running. Wait for it to finish before archiving."
        }
        do {
            try await store.requireWorkspaceCanBeRemoved(id: workspace.id)
            for session in try await store.sessions(workspaceID: workspace.id) {
                if session.id != asking, session.state == .running || session.state == .waiting {
                    return """
                        An agent is running or awaiting an answer in this workspace. Finish or \
                        stop it before archiving.
                        """
                }
                if try await !store.pendingDeliveries(sessionID: session.id).isEmpty {
                    return "This workspace has queued messages. Handle them before archiving."
                }
            }
        } catch WorkspaceError.recoveryPending {
            return WorkspaceError.recoveryPending.description
        } catch {
            return "Unified Dev could not check this workspace's activity. Nothing was archived; try again shortly."
        }
        return nil
    }
}
