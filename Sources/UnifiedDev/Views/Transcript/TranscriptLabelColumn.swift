import SwiftUI
import AppKit

struct TranscriptLabelColumn: ViewModifier {
    var text: String
    var font: ScaledFont

    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var face

    func body(content: Content) -> some View {
        content.frame(
            width: min(
                TranscriptLabelWidth.of(text, font: font, scale: fontScale, face: face),
                TranscriptLayout.labelCeiling * fontScale
            ),
            alignment: .leading
        )
    }
}

extension View {
    func transcriptLabelColumn(_ text: String, font: ScaledFont) -> some View {
        modifier(TranscriptLabelColumn(text: text, font: font))
    }
}

@MainActor
enum TranscriptLabelWidth {
    private struct Key: Hashable {
        var text: String
        var font: ScaledFont
        var scale: CGFloat
        var face: ChatFont
    }

    private static var widths: [Key: CGFloat] = [:]

    private static let limit = 512

    static func of(_ text: String, font: ScaledFont, scale: CGFloat, face: ChatFont) -> CGFloat {
        let key = Key(text: text, font: font, scale: scale, face: face)
        if let known = widths[key] { return known }

        let measured = (text as NSString)
            .size(withAttributes: [.font: font.resolvedNSFont(scale: scale, face: face)])
            .width
        let width = (measured + 1).rounded(.up)

        if widths.count >= limit { widths.removeAll(keepingCapacity: true) }
        widths[key] = width
        return width
    }
}
