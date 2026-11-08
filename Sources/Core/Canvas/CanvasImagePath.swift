import Foundation

public enum CanvasImagePath {
    public static func resolve(_ relative: String, beside document: String, worktree: String) -> String? {
        guard !relative.isEmpty, !(relative as NSString).isAbsolutePath else { return nil }
        let documentURL = URL(filePath: document, directoryHint: .notDirectory)
        let candidate = documentURL.deletingLastPathComponent().appending(path: relative)
        let root = URL(filePath: worktree, directoryHint: .isDirectory)
        return ContainedPath.resolve(candidate, inside: root)?.path
    }
}
