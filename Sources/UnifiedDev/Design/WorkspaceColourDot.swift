import SwiftUI
import AppKit
import Core

struct WorkspaceColourDot: View {
    var hex: String?
    var accessibilityName: String?

    private static let size: CGFloat = 7

    private nonisolated static let dropFromLineCentre: CGFloat = {
        let font = NSFont.preferredFont(forTextStyle: .body)
        let lineBox = (font.ascender - font.descender + font.leading).rounded()
        let baseline = (font.ascender + font.leading).rounded()
        return baseline - font.xHeight / 2 - lineBox / 2
    }()

    var body: some View {
        if let tint {
            Circle()
                .fill(tint)
                .overlay {
                    Circle().strokeBorder(Palette.textPrimary.opacity(0.12), lineWidth: Metrics.outline)
                }
                .frame(width: Self.size, height: Self.size)
                .alignmentGuide(VerticalAlignment.center) {
                    $0[VerticalAlignment.center] - Self.dropFromLineCentre
                }
                .accessibilityLabel(accessibilityName.map { "Colour \($0)" } ?? "")
                .accessibilityHidden(accessibilityName == nil)
        }
    }

    private var tint: Color? {
        guard let hex, HexColor(hex: hex) != nil else { return nil }
        return Color(hexString: hex)
    }
}

@MainActor
enum WorkspaceColourImage {
    private struct Key: Hashable {
        var hex: String
        var size: CGFloat
    }

    private static var cache: [Key: NSImage] = [:]

    static let size: CGFloat = 12

    static func of(_ hex: String, size: CGFloat = size) -> NSImage? {
        guard let colour = HexColor(hex: hex) else { return nil }
        let key = Key(hex: hex.lowercased(), size: size)
        if let cached = cache[key] { return cached }

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor(
                srgbRed: CGFloat(colour.red) / 255,
                green: CGFloat(colour.green) / 255,
                blue: CGFloat(colour.blue) / 255,
                alpha: 1
            ).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        cache[key] = image
        return image
    }
}
