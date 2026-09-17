import AppKit
import Core

struct RepoArtwork {
    var image: NSImage

    var isFullBleed: Bool
}

@MainActor
enum RepoIconArt {
    private static var cache: [String: RepoArtwork?] = [:]

    static func artwork(for repo: Repo) -> RepoArtwork? {
        guard repo.hasIcon, let path = repo.iconPath else { return nil }
        if let cached = cache[path] { return cached }
        let artwork = load(path)
        cache[path] = artwork
        return artwork
    }

    static func forget(_ path: String?) {
        guard let path else { return }
        cache.removeValue(forKey: path)
        RepoIconImage.forgetAll()
    }

    private static func load(_ path: String) -> RepoArtwork? {
        let image: NSImage?
        if path.lowercased().hasSuffix(".icon") {
            image = composite(iconBundle: path)
        } else {
            image = NSImage(contentsOfFile: path)
        }
        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        return RepoArtwork(image: image, isFullBleed: fillsItsTile(image))
    }

    private static let compositeSide: CGFloat = 256

    private static func composite(iconBundle path: String) -> NSImage? {
        let layers = RepoIconDetector.layers(ofIconBundle: path)
        guard !layers.isEmpty else { return nil }

        let side = compositeSide
        let bounds = NSRect(x: 0, y: 0, width: side, height: side)
        let canvas = NSImage(size: NSSize(width: side, height: side))
        canvas.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        var drew = false
        for layer in layers {
            guard let artwork = NSImage(contentsOfFile: layer.path) else { continue }
            painted(artwork, as: layer, in: bounds)?.draw(
                in: bounds,
                from: .zero,
                operation: .sourceOver,
                fraction: layer.opacity
            )
            drew = true
        }
        canvas.unlockFocus()
        return drew ? canvas : nil
    }

    private static func painted(_ artwork: NSImage, as layer: RepoIconLayer, in bounds: NSRect) -> NSImage? {
        guard layer.fill != .artwork else { return artwork }

        let tinted = NSImage(size: bounds.size)
        tinted.lockFocus()
        defer { tinted.unlockFocus() }
        NSGraphicsContext.current?.imageInterpolation = .high

        switch layer.fill {
        case .artwork:
            return artwork
        case let .solid(colour):
            nsColor(colour).setFill()
            bounds.fill()
        case let .linearGradient(from, to, start, stop):
            let gradient = NSGradient(starting: nsColor(from), ending: nsColor(to))
            gradient?.draw(
                from: NSPoint(x: start.x * bounds.width, y: (1 - start.y) * bounds.height),
                to: NSPoint(x: stop.x * bounds.width, y: (1 - stop.y) * bounds.height),
                options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
            )
        }

        artwork.draw(in: bounds, from: .zero, operation: .destinationIn, fraction: 1)
        return tinted
    }

    private static func nsColor(_ colour: RepoIconColour) -> NSColor {
        NSColor(
            srgbRed: colour.red,
            green: colour.green,
            blue: colour.blue,
            alpha: colour.alpha
        )
    }

    private static func fillsItsTile(_ image: NSImage) -> Bool {
        let side = 16
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return false }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: fitted(image.size, into: CGFloat(side)), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let middle = side / 2
        let edges = [(middle, 0), (middle, side - 1), (0, middle), (side - 1, middle)]
        return edges.allSatisfy { (rep.colorAt(x: $0.0, y: $0.1)?.alphaComponent ?? 0) > 0.9 }
    }

    private static func fitted(_ size: NSSize, into side: CGFloat) -> NSRect {
        let scale = min(side / size.width, side / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height)
    }
}
