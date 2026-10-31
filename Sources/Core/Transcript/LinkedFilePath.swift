import Foundation

public enum LinkedFilePath: Equatable, Sendable {
    case resolved(String)
    case onlyInCheckout(relative: String, checkout: String)

    public static func resolve(
        _ path: String, worktree: String, checkout: String?, exists: (String) -> Bool
    ) -> LinkedFilePath {
        guard !(path as NSString).isAbsolutePath else {
            return .resolved(CodeLocation(path: path).displayPath(relativeTo: worktree))
        }
        let relative = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        guard !exists((worktree as NSString).appendingPathComponent(relative)),
              let checkout,
              exists((checkout as NSString).appendingPathComponent(relative))
        else { return .resolved(relative) }
        return .onlyInCheckout(relative: relative, checkout: checkout)
    }

    public static func resolve(_ path: String, worktree: String, checkout: String?) -> LinkedFilePath {
        resolve(path, worktree: worktree, checkout: checkout) { FileManager.default.fileExists(atPath: $0) }
    }

    public func path(trackedInCheckout: Bool) -> String {
        switch self {
        case .resolved(let path):
            return path
        case let .onlyInCheckout(relative, checkout):
            return trackedInCheckout ? relative : (checkout as NSString).appendingPathComponent(relative)
        }
    }

    public func settled() async -> String {
        guard case let .onlyInCheckout(relative, checkout) = self else { return path(trackedInCheckout: false) }
        return path(trackedInCheckout: await Git.isTracked(relative, in: checkout))
    }
}
