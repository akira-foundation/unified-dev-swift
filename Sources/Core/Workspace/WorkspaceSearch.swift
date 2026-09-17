import Foundation

public enum WorkspaceSearch {
    public static func needle(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    public static func match(workspace: Workspace, repo: Repo?, needle: String) -> String? {
        guard !needle.isEmpty else { return nil }
        if workspace.name.lowercased().contains(needle) { return workspace.name }
        if workspace.branch.lowercased().contains(needle) { return workspace.branch }
        if let repo, repo.name.lowercased().contains(needle) { return repo.name }
        return nil
    }

    public static func matchesOrIsUnfiltered(workspace: Workspace, repo: Repo?, needle: String) -> Bool {
        needle.isEmpty || match(workspace: workspace, repo: repo, needle: needle) != nil
    }
}
