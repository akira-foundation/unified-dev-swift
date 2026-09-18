import Foundation

public enum WorkspaceDraftMove: Equatable, Sendable {
    case goTo(RepoID)
    case move(WorkspaceDraft)

    public static func decide(_ draft: WorkspaceDraft, to target: Repo, targetHasDraft: Bool) -> Self {
        guard !targetHasDraft else { return .goTo(target.id) }
        var moved = draft
        moved.repoID = target.id
        moved.startingPoint = .newBranch(from: target.defaultBranch)
        return .move(moved)
    }
}
