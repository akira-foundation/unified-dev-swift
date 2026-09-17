import AppKit
import Core
import SwiftUI

enum CodeMetrics {
    nonisolated(unsafe) static let font: NSFont = {
        let size = NSFont.preferredFont(forTextStyle: .callout).pointSize
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }()

    nonisolated(unsafe) static let numberFont: NSFont = {
        let size = NSFont.preferredFont(forTextStyle: .footnote).pointSize
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }()

    static let measuredFont = Font(font)

    static let advance: CGFloat = advance(of: font, fallback: 7.2)

    static let numberAdvance: CGFloat = advance(of: numberFont, fallback: 6)

    private static func advance(of font: NSFont, fallback: CGFloat) -> CGFloat {
        let width = ("0" as NSString).size(withAttributes: [.font: font]).width
        return width > 0 ? width : fallback
    }

    static let naturalLineHeight: CGFloat = ceil(font.ascender - font.descender + font.leading)

    static let rowHeight: CGFloat = max(16, naturalLineHeight + 3)

    static let rowSpacing: CGFloat = rowHeight - naturalLineHeight

    static let markerWidth: CGFloat = ceil(advance) + 4

    static let numberWidth: CGFloat = ceil(numberAdvance * 4) + gutterPadding

    static let gutterPadding: CGFloat = 4
    static let textInset: CGFloat = 8

    static func columns(of line: String) -> Int { CodeColumns.count(of: line) }
}
