import Foundation

public enum ProjectDefaultBranch {
    public static func refresh(_ repo: Repo, in store: Store) async -> Repo {
        await adopt(Git.remoteDefaultBranch(of: repo.path), for: repo, in: store)
    }

    static func adopt(_ announced: String?, for repo: Repo, in store: Store) async -> Repo {
        guard let announced, announced != repo.defaultBranch else { return repo }
        let observed = repo.defaultBranch
        let stored = try? await store.update(repoID: repo.id) { row in
            guard row.defaultBranch == observed else { return }
            row.defaultBranch = announced
        }
        return stored ?? repo
    }

    public static func startingPoint(
        _ point: WorkspaceStartingPoint, after old: String, became new: String
    ) -> WorkspaceStartingPoint {
        point == .newBranch(from: old) ? .newBranch(from: new) : point
    }
}
