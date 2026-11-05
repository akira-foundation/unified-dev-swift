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

    public static func overlapArea(_ rect: CanvasRect, _ other: CanvasRect) -> Double {
        let width = min(rect.origin.x + max(rect.size.width, 1), other.origin.x + other.size.width) - max(rect.origin.x, other.origin.x)
        let height = min(rect.origin.y + max(rect.size.height, 1), other.origin.y + other.size.height) - max(rect.origin.y, other.origin.y)
        return width > 0 && height > 0 ? width * height : 0
    }

    public static func frame(overlapping rect: CanvasRect, keeping current: CanvasFrameID? = nil, in document: CanvasDocument) -> CanvasFrame? {
        let best = document.frames.map { overlapArea(rect, $0.rect) }.max() ?? 0
        guard best > 0 else { return nil }
        if let current, let kept = document.frames.first(where: { $0.id == current }), overlapArea(rect, kept.rect) >= best { return kept }
        return document.frames.last { overlapArea(rect, $0.rect) >= best }
    }

    public static func frame(holding points: [CanvasPoint], in document: CanvasDocument) -> CanvasFrame? {
        func count(_ frame: CanvasFrame) -> Int {
            points.filter { contains(frame, $0) }.count
        }
        let best = document.frames.map(count).max() ?? 0
        guard best > 0 else { return nil }
        return document.frames.last { count($0) >= best }
    }

    private static func contains(_ frame: CanvasFrame, _ point: CanvasPoint) -> Bool {
        point.x >= frame.rect.origin.x && point.x <= frame.rect.origin.x + frame.rect.size.width
            && point.y >= frame.rect.origin.y && point.y <= frame.rect.origin.y + frame.rect.size.height
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

    public static let defaultShapeWidth = 240.0
    public static let defaultShapeHeight = 160.0
    public static let lineBoxHeight = 24.0
    public static let defaultNoteWidth = 360.0
    public static let defaultNoteHeight = 240.0
    public static let shapeStroke = "#111827"
    public static let shapeStrokeWidth = 6.0
    public static let noteFill = "#FFE98A"

    public static func newShape(
        _ kind: CanvasShape.Kind, from start: CanvasPoint, to end: CanvasPoint, in document: CanvasDocument
    ) -> CanvasElement {
        let isLine = kind == .line || kind == .arrow
        let length = hypot(end.x - start.x, end.y - start.y)
        let (box, rotation) = shapeBox(isLine: isLine, from: start, to: end, length: length)
        let frame = frame(overlapping: box, in: document)
        let origin = frame?.rect.origin ?? CanvasPoint(x: 0, y: 0)
        return CanvasElement(
            frameID: frame?.id,
            rect: CanvasRect(x: box.origin.x - origin.x, y: box.origin.y - origin.y, width: box.size.width, height: box.size.height),
            style: CanvasStyle(stroke: shapeStroke, strokeWidth: shapeStrokeWidth, rotation: rotation),
            kind: .shape(CanvasShape(kind: kind))
        )
    }

    private static func shapeBox(isLine: Bool, from: CanvasPoint, to: CanvasPoint, length: Double) -> (CanvasRect, Double) {
        guard length >= 1 else {
            let height = isLine ? lineBoxHeight : defaultShapeHeight
            let box = CanvasRect(x: from.x - defaultShapeWidth / 2, y: from.y - height / 2, width: defaultShapeWidth, height: height)
            return (box, 0)
        }
        guard isLine else {
            let width = max(abs(to.x - from.x), CanvasResize.minimumSide)
            let height = max(abs(to.y - from.y), CanvasResize.minimumSide)
            return (CanvasRect(x: min(from.x, to.x), y: min(from.y, to.y), width: width, height: height), 0)
        }
        let middle = CanvasPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let box = CanvasRect(x: middle.x - length / 2, y: middle.y - lineBoxHeight / 2, width: length, height: lineBoxHeight)
        return (box, atan2(to.y - from.y, to.x - from.x) * 180 / .pi)
    }

    public static func newNote(at point: CanvasPoint, in document: CanvasDocument) -> CanvasElement {
        let run = CanvasTextRun(text: "", fontName: "Helvetica Neue", size: 36, weight: 0, colour: "#111827")
        let frame = frame(containing: point, in: document)
        let origin = frame?.rect.origin ?? CanvasPoint(x: 0, y: 0)
        var x = point.x - origin.x
        var y = point.y - origin.y
        if let frame {
            x = max(min(x, frame.rect.size.width - defaultNoteWidth), 0)
            y = max(min(y, frame.rect.size.height - defaultNoteHeight), 0)
        }
        return CanvasElement(
            frameID: frame?.id,
            rect: CanvasRect(x: x, y: y, width: defaultNoteWidth, height: defaultNoteHeight),
            style: CanvasStyle(fill: noteFill, cornerRadius: 8),
            kind: .note(CanvasText(runs: [run]))
        )
    }

    public static func imageTarget(centre: CanvasPoint, in document: CanvasDocument) -> CanvasFrame? {
        frame(containing: centre, in: document) ?? document.frames.first
    }
}
