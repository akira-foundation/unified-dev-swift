import Foundation

public struct GitHubLoginRoutes: Sendable, Hashable {
    public struct Route: Sendable, Hashable {
        public let path: String
        public let profile: ProfileID

        public init(path: String, profile: ProfileID) {
            self.path = GitHubLoginRoutes.normalised(path)
            self.profile = profile
        }
    }

    public let routes: [Route]

    public init(routes: [Route]) {
        self.routes = routes.filter { !$0.path.isEmpty }.sorted { $0.path.count > $1.path.count }
    }

    public init(repos: [Repo], workspaces: [Workspace]) {
        let owners = Dictionary(repos.map { ($0.id, $0.profileID) }, uniquingKeysWith: { first, _ in first })
        let repoRoutes = repos.map { Route(path: $0.path, profile: $0.profileID) }
        let workspaceRoutes = workspaces.compactMap { workspace in
            owners[workspace.repoID].map { Route(path: workspace.path, profile: $0) }
        }
        self.init(routes: workspaceRoutes + repoRoutes)
    }

    public func profile(forDirectory directory: String) -> ProfileID? {
        let wanted = Self.normalised(directory)
        guard !wanted.isEmpty else { return nil }
        return routes.first { route in
            wanted == route.path || wanted.hasPrefix(route.path == "/" ? "/" : route.path + "/")
        }?.profile
    }

    static func normalised(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let standard = (path as NSString).standardizingPath
        return standard.count > 1 && standard.hasSuffix("/") ? String(standard.dropLast()) : standard
    }
}
