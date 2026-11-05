import AppKit
import Core

@MainActor
extension MarkdownTextStyle {
    func indent(of piece: MarkdownPiece) -> (first: CGFloat, head: CGFloat, marker: CGFloat) {
        let marker = MarkdownMetrics.markerWidth * scale
        let step = marker + Metrics.spacingSmall
        let base = CGFloat(max(0, piece.listDepth - 1)) * step
        guard piece.listDepth > 0 else { return (0, 0, 0) }
        return (base, base + step, base + marker)
    }

    func paragraph(for piece: MarkdownPiece, containers: [NSTextBlock]) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        let indent = indent(of: piece)
        paragraph.lineSpacing = piece.isTask ? taskLeading : leading
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.headIndent = indent.head
        paragraph.firstLineHeadIndent = piece.marker == nil ? indent.head : indent.first
        paragraph.textBlocks = containers
        if piece.marker != nil {
            paragraph.tabStops = [
                NSTextTab(textAlignment: .right, location: indent.marker),
                NSTextTab(textAlignment: .left, location: indent.head),
            ]
            paragraph.defaultTabInterval = 0
        }
        return paragraph
    }

    func boxed(_ blocks: [NSTextBlock]) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = leading
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.textBlocks = blocks
        return paragraph
    }

    static func softenBreaks(in body: NSMutableAttributedString) {
        body.mutableString.replaceOccurrences(
            of: "\n", with: MarkdownSelectionCopy.softBreak,
            range: NSRange(location: 0, length: body.length)
        )
    }
}
