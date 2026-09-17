import Core

struct TranscriptHome: Hashable {
    var workspaceID: WorkspaceID?
    var worktree: String

    init(workspaceID: WorkspaceID? = nil, worktree: String = "") {
        self.workspaceID = workspaceID
        self.worktree = worktree
    }

    init(_ workspace: Workspace) {
        self.workspaceID = workspace.id
        self.worktree = workspace.path
    }
}
