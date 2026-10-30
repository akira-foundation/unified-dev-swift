import Foundation

public enum RecentProjects {
    public static let limit = 10

    public static func ordered(
        _ repos: [Repo], activity: [RepoID: Date], limit: Int = RecentProjects.limit
    ) -> [Repo] {
        let listed = ProjectVisibility.listed(repos, showingHidden: false)
        let worked = listed.compactMap { repo in
            activity[repo.id].map { (repo: repo, lastActive: $0) }
        }

        let ordered = worked.sorted { left, right in
            guard left.lastActive == right.lastActive else { return left.lastActive > right.lastActive }
            return left.repo.name.localizedStandardCompare(right.repo.name) == .orderedAscending
        }

        return ordered.prefix(max(0, limit)).map { $0.repo }
    }
}
