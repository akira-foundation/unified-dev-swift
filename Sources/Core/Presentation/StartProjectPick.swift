import Foundation

public enum StartProjectPick {
    public static func offered(_ repos: [Repo], showingHidden: Bool) -> [Repo] {
        ProjectVisibility.listed(repos, showingHidden: showingHidden)
    }

    public static func opens(
        repo: Repo,
        workspaces: [Workspace],
        drawn: (Workspace) -> Bool
    ) -> WorkspaceID? {
        workspaces.first { $0.repoID == repo.id && $0.state == .active && drawn($0) }?.id
    }
}
