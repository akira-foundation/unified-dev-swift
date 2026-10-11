import Foundation

public enum SpendProjects {
    public struct Placement: Sendable, Hashable {
        public var repoID: RepoID?
        public var name: String
        public var path: String

        public init(repoID: RepoID?, name: String, path: String) {
            self.repoID = repoID
            self.name = name
            self.path = path
        }
    }

    public static let elsewhere = "Outside your projects"

    public static func placement(
        of directory: String,
        workspaces: [Workspace],
        repos: [Repo]
    ) -> Placement {
        if let repoID = repo(of: directory, workspaces: workspaces, repos: repos),
           let repo = repos.first(where: { $0.id == repoID }) {
            return Placement(repoID: repo.id, name: repo.name, path: repo.path)
        }
        return Placement(repoID: nil, name: elsewhere, path: directory)
    }

    static func repo(of directory: String, workspaces: [Workspace], repos: [Repo]) -> RepoID? {
        let inWorkspace = workspaces
            .filter { contains(path: $0.path, directory: directory) }
            .max { $0.path.count < $1.path.count }
        if let inWorkspace { return inWorkspace.repoID }

        return repos
            .filter { contains(path: $0.path, directory: directory) }
            .max { $0.path.count < $1.path.count }?
            .id
    }

    static func contains(path: String, directory: String) -> Bool {
        guard !path.isEmpty, !directory.isEmpty else { return false }
        if directory == path { return true }
        return directory.hasPrefix(path.hasSuffix("/") ? path : path + "/")
    }
}
