import AppKit
import Core

enum CanvasImageLoading {
    static let cache = CanvasImageCache { path, side in
        CanvasImageFile.decoded(path, longestSide: side) ?? rasterisedVector(path, longestSide: side)
    }

    private static func rasterisedVector(_ path: String, longestSide: Int) -> CGImage? {
        guard let image = NSImage(contentsOfFile: path), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = Double(longestSide) / max(image.size.width, image.size.height)
        var rect = CGRect(x: 0, y: 0, width: (image.size.width * scale).rounded(.up), height: (image.size.height * scale).rounded(.up))
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

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
