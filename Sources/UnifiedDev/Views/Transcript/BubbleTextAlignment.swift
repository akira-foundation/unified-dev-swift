import AppKit
import CoreText
import Core

enum BubbleTextAlignment {
    static func offset(layout: NSLayoutManager, container: NSTextContainer) -> CGFloat {
        guard let storage = layout.textStorage, layout.numberOfGlyphs > 0 else { return 0 }
        let first = ink(at: 0, layout: layout, storage: storage)
        let last = ink(at: layout.numberOfGlyphs - 1, layout: layout, storage: storage)
        guard let first, let last else { return 0 }
        return TranscriptTextMeasure.bubbleTextOffset(
            height: layout.usedRect(for: container).height,
            inkTop: first.minY,
            inkBottom: last.maxY
        )
    }

    private static func ink(at glyph: Int, layout: NSLayoutManager, storage: NSTextStorage) -> CGRect? {
        var range = NSRange()
        let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
        let characters = layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
        let text = storage.attributedSubstring(from: characters)
        var hasAttachment = false
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if value != nil { hasAttachment = true }
        }
        guard !hasAttachment else { return nil }
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard !bounds.isEmpty else { return nil }
        let baseline = fragment.minY + layout.location(forGlyphAt: range.location).y
        return CGRect(x: bounds.minX, y: baseline - bounds.maxY, width: bounds.width, height: bounds.height)
    }
}
