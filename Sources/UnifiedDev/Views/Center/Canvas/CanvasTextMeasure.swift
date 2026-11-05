import AppKit
import Core

enum CanvasTextMeasure {
    static func sizes(in document: CanvasDocument) -> [CanvasElementID: CanvasSize] {
        document.elements.reduce(into: [:]) { sizes, element in
            switch element.kind {
            case .text(let text): sizes[element.id] = size(of: text, width: element.rect.size.width)
            case .note(let text): sizes[element.id] = size(of: text, width: element.rect.size.width - 24, padding: 24)
            default: break
            }
        }
    }

    static func size(of text: CanvasText, width: Double, padding: Double = 0) -> CanvasSize {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment(text.alignment)
        let attributed = NSMutableAttributedString()
        for run in text.runs {
            attributed.append(NSAttributedString(string: run.text, attributes: [
                .font: font(for: run),
                .paragraphStyle: paragraph,
            ]))
        }
        let bounds = attributed.boundingRect(
            with: NSSize(width: max(width, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CanvasSize(width: ceil(bounds.width) + padding, height: ceil(bounds.height) + padding)
    }

    static func font(for run: CanvasTextRun) -> NSFont {
        let weight = NSFont.Weight(rawValue: CanvasFontWeight.nearest(to: run.weight).value)
        guard let base = NSFont(name: run.fontName, size: run.size) else {
            return NSFont.systemFont(ofSize: run.size, weight: weight)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue],
        ])
        return NSFont(descriptor: descriptor, size: run.size) ?? base
    }

    private static func alignment(_ alignment: CanvasText.Alignment) -> NSTextAlignment {
        switch alignment {
        case .leading: .left
        case .centre: .center
        case .trailing: .right
        }
    }
}
