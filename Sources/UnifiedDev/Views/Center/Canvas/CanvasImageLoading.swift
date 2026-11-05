import AppKit
import Core

enum CanvasImageLoading {
    static func image(_ relative: String, documentPath: String, worktree: String) -> NSImage? {
        CanvasImagePath.resolve(relative, beside: documentPath, worktree: worktree).flatMap(image(atResolved:))
    }

    static func image(atResolved path: String) -> NSImage? {
        guard CanvasImageFile.admits(path) else { return nil }
        return NSImage(contentsOfFile: path)
    }

    static func draws(_ resolved: String) -> Bool {
        image(atResolved: resolved) != nil
    }
}
