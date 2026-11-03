import Foundation

public enum CanvasFocusHolder: Sendable, Equatable {
    case nothing, closingEditor, somethingElse
}

public enum CanvasEditing {
    public static func returnsFocus(from holder: CanvasFocusHolder) -> Bool {
        holder != .somethingElse
    }

    public static let defaultTextWidth = 640.0
    public static let defaultTextHeight = 96.0
    private static let minimumTextWidth = 40.0
    private static let notePadding = 24.0

    public static func number(from typed: String, format: FloatingPointFormatStyle<Double>) -> Double? {
        try? format.parseStrategy.parse(typed)
    }

    public static func notePadding(of element: CanvasElement) -> Double {
        element.isNote ? notePadding : 0
    }

    public static func operations(
        finishing id: CanvasElementID,
        original: CanvasText,
        edited: CanvasText,
        measuredHeight: Double,
        in document: CanvasDocument
    ) -> [CanvasOperation] {
        guard edited != original, let element = document.elements.first(where: { $0.id == id }) else { return [] }
        var rect = element.rect
        rect.size.height = max(rect.size.height, measuredHeight)
        return [.updateElement(
            id, expectedRevision: nil, CanvasElementPatch(rect: rect, kind: element.kind(replacingTextWith: edited))
        )]
    }

    public static func frame(containing point: CanvasPoint, in document: CanvasDocument) -> CanvasFrame? {
        document.frames.last { frame in
            point.x >= frame.rect.origin.x && point.x <= frame.rect.origin.x + frame.rect.size.width
                && point.y >= frame.rect.origin.y && point.y <= frame.rect.origin.y + frame.rect.size.height
        }
    }

    public static func newText(at point: CanvasPoint, in document: CanvasDocument) -> CanvasElement {
        let run = CanvasTextRun(text: "", fontName: "Helvetica Neue", size: 64, weight: 0, colour: "#111827")
        let kind = CanvasElement.Kind.text(CanvasText(runs: [run]))
        guard let frame = frame(containing: point, in: document) else {
            return CanvasElement(
                rect: CanvasRect(x: point.x, y: point.y, width: defaultTextWidth, height: defaultTextHeight), kind: kind
            )
        }
        let x = point.x - frame.rect.origin.x
        let width = max(min(defaultTextWidth, frame.rect.size.width - x), minimumTextWidth)
        return CanvasElement(
            frameID: frame.id,
            rect: CanvasRect(x: x, y: point.y - frame.rect.origin.y, width: width, height: defaultTextHeight),
            kind: kind
        )
    }

    public static func imageTarget(centre: CanvasPoint, in document: CanvasDocument) -> CanvasFrame? {
        frame(containing: centre, in: document) ?? document.frames.first
    }
}
