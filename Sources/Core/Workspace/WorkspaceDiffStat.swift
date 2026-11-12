import Foundation

public struct WorkspaceDiffStat: Sendable, Hashable {
    public var additions: Int
    public var deletions: Int
    public var files: Int

    public init(additions: Int, deletions: Int, files: Int) {
        self.additions = additions
        self.deletions = deletions
        self.files = files
    }

    public init(of workspace: Workspace) {
        self.init(
            additions: workspace.additions, deletions: workspace.deletions, files: workspace.changedFiles
        )
    }

    public static func applied(
        _ stats: [WorkspaceID: WorkspaceDiffStat], to workspaces: [Workspace]
    ) -> [Workspace]? {
        var updated = workspaces
        var changed = false
        for index in updated.indices {
            guard let stat = stats[updated[index].id], stat != WorkspaceDiffStat(of: updated[index]) else {
                continue
            }
            updated[index].additions = stat.additions
            updated[index].deletions = stat.deletions
            updated[index].changedFiles = stat.files
            changed = true
        }
        return changed ? updated : nil
    }
}
