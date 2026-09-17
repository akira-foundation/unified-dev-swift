import SwiftUI
import AppKit
import Core

@MainActor
enum RepoIconImage {
    private struct Key: Hashable {
        var name: String
        var accent: String?
        var artwork: String?
        var size: CGFloat
        var scale: CGFloat
    }

    private static var cache: [Key: NSImage] = [:]

    static func of(_ repo: Repo, size: CGFloat = Metrics.repoIcon) -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let key = Key(
            name: repo.name,
            accent: repo.accent,
            artwork: repo.hasIcon ? repo.iconPath : nil,
            size: size,
            scale: scale
        )
        if let cached = cache[key] { return cached }

        let renderer = ImageRenderer(content: RepoIcon(repo: repo, size: size))
        renderer.scale = scale
        guard let image = renderer.nsImage else { return nil }
        cache[key] = image
        return image
    }

    static func forgetAll() {
        cache.removeAll()
    }
}
