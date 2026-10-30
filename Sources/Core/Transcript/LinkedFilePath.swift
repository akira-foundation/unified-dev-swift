import Foundation

public enum LinkedFilePath {
    public static func resolve(
        _ path: String, worktree: String, checkout: String?, exists: (String) -> Bool
    ) -> String {
        guard !(path as NSString).isAbsolutePath else { return path }
        let relative = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        if exists((worktree as NSString).appendingPathComponent(relative)) { return relative }
        guard let checkout, checkout != worktree else { return path }
        let inCheckout = (checkout as NSString).appendingPathComponent(relative)
        return exists(inCheckout) ? inCheckout : path
    }

    public static func resolve(_ path: String, worktree: String, checkout: String?) -> String {
        resolve(path, worktree: worktree, checkout: checkout) { FileManager.default.fileExists(atPath: $0) }
    }
}
