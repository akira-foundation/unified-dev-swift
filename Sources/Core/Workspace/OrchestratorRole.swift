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

    public static func watchesStartedWorkspaces(requested: Bool, callerIsOrchestrator: Bool) -> Bool {
        requested || callerIsOrchestrator
    }

    public static func announcedOrchestrator(for started: Workspace, among workspaces: [Workspace]) -> Workspace? {
        guard !started.isOrchestrator,
              let orchestrator = workspaces.first(where: {
                  $0.repoID == started.repoID && $0.isOrchestrator && $0.state == .active && $0.id != started.id
              }),
              started.origin.parentWorkspaceID != orchestrator.id
        else { return nil }
        return orchestrator
    }

    public static let instructions = """
        This chat runs in the orchestrator workspace of this project in Unified Dev. Nothing is \
        implemented here: no agent in this workspace edits, writes or deletes files in its worktree, \
        or commits, pushes, merges or rebases. Unified Dev refuses file edits, terminals, tools \
        it does not know and those git commands here, and asks the owner before any other \
        command. The work here is to plan, \
        to start other workspaces with workspace_start for every piece of implementation, to follow \
        them with workspace_list, workspace_diff and chat_read, to answer them with workspace_say, \
        and to gather what they report into one account for the owner. Unified Dev tells this chat \
        about every workspace started in this project, whoever starts it, and again when its first \
        turn comes to rest. Reading files, searching and asking GitHub are fine.
        """
}
