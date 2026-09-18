import Foundation

public enum NewWorkspaceTarget {
    public static func project(
        requested: RepoID?, selection: SidebarSelection, workspaces: [Workspace], repos: [Repo]
    ) -> Repo? {
        let selectedWorkspace = selection.workspaceID.flatMap { id in
            workspaces.first { $0.id == id }?.repoID
        }
        for candidate in [requested, selection.draftRepoID, selectedWorkspace].compactMap({ $0 }) {
            if let repo = repos.first(where: { $0.id == candidate }) { return repo }
        }
        return ProjectVisibility.listed(repos, showingHidden: false).first
    }
}
