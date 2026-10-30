import Foundation

public enum LinkedFilePath {
    public static func resolve(
        _ path: String,
        worktree: String,
        checkout: String?,
        changed: Set<String> = [],
        exists: (String) -> Bool
    ) -> String {
        guard !(path as NSString).isAbsolutePath else {
            return CodeLocation(path: path).displayPath(relativeTo: worktree)
        }
        let relative = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        if changed.contains(relative) || exists((worktree as NSString).appendingPathComponent(relative)) {
            return relative
        }
        guard let checkout else { return relative }
        let inCheckout = (checkout as NSString).appendingPathComponent(relative)
        return exists(inCheckout) ? inCheckout : relative
    }

    public static func resolve(
        _ path: String, worktree: String, checkout: String?, changed: Set<String> = []
    ) -> String {
        resolve(path, worktree: worktree, checkout: checkout, changed: changed) {
            FileManager.default.fileExists(atPath: $0)
        }
    }
}
