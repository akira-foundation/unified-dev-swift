import AppKit
import Observation
import SwiftUI
import Core

@MainActor
@Observable
final class CanvasTextEditing {
    let elementID: CanvasElementID
    let original: CanvasText
    var text: CanvasText
    var selection = NSRange(location: 0, length: 0)
    var revision = 0

    init(elementID: CanvasElementID, text: CanvasText) {
        self.elementID = elementID
        self.original = text
        self.text = text
    }

    var plain: String { text.runs.map(\.text).joined() }

    var selectedCharacters: Range<Int> {
        let range = CanvasTextStyling.characterRange(of: selection, in: plain)
        return range.isEmpty ? 0..<plain.count : range
    }

    func apply(_ change: CanvasRunChange) {
        text = CanvasTextStyling.applying(change, range: selectedCharacters, to: text)
        revision += 1
    }
}

extension NSColor {
    convenience init(canvas text: String) {
        let parsed = CanvasColour(text) ?? CanvasColour(red: 0, green: 0, blue: 0, alpha: 1)
        self.init(srgbRed: parsed.red, green: parsed.green, blue: parsed.blue, alpha: parsed.alpha)
    }
}

private extension NSAttributedString.Key {
    static let canvasFontName = NSAttributedString.Key("canvas.fontName")
    static let canvasSize = NSAttributedString.Key("canvas.size")
    static let canvasWeight = NSAttributedString.Key("canvas.weight")
    static let canvasColour = NSAttributedString.Key("canvas.colour")
}

struct CanvasTextEditor: NSViewRepresentable {
    let editing: CanvasTextEditing
    let width: Double
    let height: Double
    let finish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(editing: editing) }

    func makeNSView(context: Context) -> CanvasEditingTextView {
        let view = CanvasEditingTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.drawsBackground = false
        view.isRichText = true
        view.allowsUndo = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.delegate = context.coordinator
        view.onEscape = finish
        context.coordinator.load(into: view)
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ view: CanvasEditingTextView, context: Context) {
        view.onEscape = finish
        guard context.coordinator.appliedRevision != editing.revision else { return }
        context.coordinator.load(into: view)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let editing: CanvasTextEditing
        var appliedRevision = -1
        private var loading = false

        init(editing: CanvasTextEditing) { self.editing = editing }

        func load(into view: NSTextView) {
            loading = true
            defer { loading = false }
            appliedRevision = editing.revision
            let selection = editing.selection
            view.textStorage?.setAttributedString(Self.attributed(editing.text))
            let length = view.textStorage?.length ?? 0
            view.setSelectedRange(NSRange(location: min(selection.location, length), length: min(selection.length, max(length - selection.location, 0))))
            if let first = editing.text.runs.first { view.typingAttributes = Self.attributes(for: first, alignment: editing.text.alignment) }
        }

        func textDidChange(_ notification: Notification) {
            guard !loading, let view = notification.object as? NSTextView else { return }
            editing.text = Self.runs(from: view.attributedString(), like: editing.text)
            editing.selection = view.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !loading, let view = notification.object as? NSTextView else { return }
            editing.selection = view.selectedRange()
        }

        private static func paragraph(_ alignment: CanvasText.Alignment) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.alignment = switch alignment {
            case .leading: .left
            case .centre: .center
            case .trailing: .right
            }
            return style
        }

        private static func font(for run: CanvasTextRun) -> NSFont {
            let base = CanvasTextMeasure.font(for: run)
            guard run.weight >= CanvasFontWeight.semibold.value else { return base }
            return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        }

        private static func attributes(for run: CanvasTextRun, alignment: CanvasText.Alignment) -> [NSAttributedString.Key: Any] {
            [
                .font: font(for: run),
                .foregroundColor: NSColor(canvas: run.colour),
                .paragraphStyle: paragraph(alignment),
                .canvasFontName: run.fontName,
                .canvasSize: run.size,
                .canvasWeight: run.weight,
                .canvasColour: run.colour,
            ]
        }

        private static func attributed(_ text: CanvasText) -> NSAttributedString {
            let result = NSMutableAttributedString()
            for run in text.runs {
                result.append(NSAttributedString(string: run.text, attributes: attributes(for: run, alignment: text.alignment)))
            }
            return result
        }

        private static func runs(from string: NSAttributedString, like text: CanvasText) -> CanvasText {
            let fallback = text.runs.first ?? CanvasTextRun(text: "", fontName: "Helvetica Neue", size: 64, weight: 0, colour: "#111827")
            var runs: [CanvasTextRun] = []
            string.enumerateAttributes(in: NSRange(location: 0, length: string.length)) { attributes, range, _ in
                runs.append(CanvasTextRun(
                    text: string.attributedSubstring(from: range).string,
                    fontName: attributes[.canvasFontName] as? String ?? fallback.fontName,
                    size: attributes[.canvasSize] as? Double ?? fallback.size,
                    weight: attributes[.canvasWeight] as? Double ?? fallback.weight,
                    colour: attributes[.canvasColour] as? String ?? fallback.colour
                ))
            }
            if runs.isEmpty {
                var empty = fallback
                empty.text = ""
                runs = [empty]
            }
            return CanvasTextStyling.normalised(runs, alignment: text.alignment)
        }
    }
}

final class CanvasEditingTextView: NSTextView {
    var onEscape: () -> Void = {}

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }
}
