import AppKit
import Core
import SwiftUI

enum MarkdownTextMarker {
    @MainActor
    static func make(
        _ marker: MarkdownPiece.Marker, font: NSFont, body: NSFont, attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        var attributes = attributes
        attributes[.markdownMarker] = true
        attributes[.foregroundColor] = NSColor.secondaryLabelColor
        attributes[.font] = body
        let output = NSMutableAttributedString(string: "\t", attributes: attributes)
        if case let .task(checked) = marker {
            let attachment = NSTextAttachment()
            attachment.image = taskImage(checked: checked)
            let size = ceil(font.pointSize)
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - size) / 2, width: size, height: size)
            let mark = NSMutableAttributedString(attachment: attachment)
            mark.addAttributes(attributes, range: NSRange(location: 0, length: mark.length))
            output.append(mark)
        } else {
            attributes[.font] = tabular(body)
            output.append(NSAttributedString(string: marker.written, attributes: attributes))
        }
        output.append(NSAttributedString(string: "\t", attributes: attributes))
        return output
    }

    private static func tabular(_ font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: [[
            NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
            NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
        ]]])
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    @MainActor
    private static func taskImage(checked: Bool) -> NSImage? {
        let symbol = checked ? "checkmark.square.fill" : "square"
        let tint = checked ? NSColor(Palette.positive) : NSColor.tertiaryLabelColor
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: checked ? "Done" : "Not done")
        return image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [tint]))
    }
}
