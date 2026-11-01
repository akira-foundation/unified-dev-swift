import Foundation

public enum OrchestratorRole {
    public enum Assignment: Equatable, Sendable {
        case allowed
        case refused(String)
    }

    public static func asksAtCreation(repoID: RepoID, workspaces: [Workspace]) -> Bool {
        !workspaces.contains { $0.repoID == repoID && ($0.state == .active || $0.isOrchestrator) }
    }

    public static func assignment(of workspace: Workspace, among workspaces: [Workspace]) -> Assignment {
        guard workspace.state == .active else {
            return .refused("\(workspace.name) is archived, so it cannot be the project's orchestrator.")
        }
        return assignment(in: workspace.repoID, replacing: workspace.id, among: workspaces)
    }

    public static func assignment(
        in repoID: RepoID, replacing candidate: WorkspaceID? = nil, among workspaces: [Workspace]
    ) -> Assignment {
        if let current = workspaces.first(where: {
            $0.repoID == repoID && $0.isOrchestrator && $0.id != candidate
        }) {
            return .refused(
                "\(current.name) is already this project's orchestrator. A project has one; "
                    + "stop \(current.name) being the orchestrator first."
            )
        }
        return .allowed
    }

    public static func pinned(_ requested: Bool, isOrchestrator: Bool) -> Bool {
        requested || isOrchestrator
    }

    public static func archiveObjection(to workspace: Workspace) -> String? {
        guard workspace.isOrchestrator else { return nil }
        return "\(workspace.name) is this project's orchestrator, so it is never archived. "
            + "Stop it being the orchestrator first if you want it gone."
    }

    public static func children(of orchestrator: WorkspaceID, in workspaces: [Workspace]) -> [Workspace] {
        workspaces
            .filter { $0.origin.parentWorkspaceID == orchestrator }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public static func watchesStartedWorkspaces(requested: Bool, callerIsOrchestrator: Bool) -> Bool {
        requested || callerIsOrchestrator
    }

    public static let instructions = """
        You are the orchestrator of this project in Unified Dev. You never implement anything \
        yourself: you do not edit, write or delete files in this worktree, and you do not commit, \
        push, merge or rebase here. Unified Dev refuses those calls in this workspace. Your work is \
        to plan, to start other workspaces with workspace_start for every piece of implementation, \
        to follow them with workspace_list, workspace_diff and chat_read, to answer them with \
        workspace_say, and to gather what they report into one account for the owner. Unified Dev \
        tells you when the first turn of each workspace you start comes to rest. Reading files, \
        searching and asking GitHub are fine.
        """
}
