import Foundation

public enum WorktreeScratch {
    public static let attachments = ".unifieddev/attachments"

    public static let generated = ".unifieddev/scratch"

    public static let folders = [attachments, generated]

    public static func isShielded(_ path: String) -> Bool {
        folders.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    public static func shield(_ folder: String = attachments, in worktree: String) {
        let full = (worktree as NSString).appendingPathComponent(folder)
        let ignore = (full as NSString).appendingPathComponent(".gitignore")
        let manager = FileManager.default
        guard !manager.fileExists(atPath: ignore) else { return }
        guard manager.fileExists(atPath: worktree) else { return }
        try? manager.createDirectory(atPath: full, withIntermediateDirectories: true)
        try? "*\n".write(toFile: ignore, atomically: true, encoding: .utf8)
    }
}
