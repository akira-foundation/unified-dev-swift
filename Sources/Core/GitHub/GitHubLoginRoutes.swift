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
        self.routes = routes.filter { !$0.path.isEmpty }.sorted {
            $0.path.count == $1.path.count ? $0.path < $1.path : $0.path.count > $1.path.count
        }
    }

    public func profile(forDirectory directory: String) -> ProfileID? {
        guard !directory.isEmpty else { return nil }
        let resolved = URL(filePath: directory).resolvingSymlinksInPath().path
        let candidates = Set([Self.normalised(directory), Self.normalised(resolved)])
        return routes.first { route in candidates.contains { Self.holds(route.path, $0) } }?.profile
    }

    private static func holds(_ route: String, _ wanted: String) -> Bool {
        wanted == route || wanted.hasPrefix(route == "/" ? "/" : route + "/")
    }

    static func normalised(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let standard = (path as NSString).standardizingPath
        return standard.count > 1 && standard.hasSuffix("/") ? String(standard.dropLast()) : standard
    }
}
