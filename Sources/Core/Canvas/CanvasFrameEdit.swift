import Foundation

public enum CanvasFrameEdit {
    public static func operations(renaming id: CanvasFrameID, to name: String, in document: CanvasDocument) -> [CanvasOperation] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let frame = frame(id, in: document), frame.name != trimmed else { return [] }
        return [.updateFrame(id, expectedRevision: nil, CanvasFramePatch(name: trimmed))]
    }

    public static func operations(filling id: CanvasFrameID, with fill: String, in document: CanvasDocument) -> [CanvasOperation] {
        guard let frame = frame(id, in: document), frame.fill != fill else { return [] }
        return [.updateFrame(id, expectedRevision: nil, CanvasFramePatch(fill: fill))]
    }

    public static func operations(placing id: CanvasFrameID, x: Double? = nil, y: Double? = nil, in document: CanvasDocument) -> [CanvasOperation] {
        guard let frame = frame(id, in: document) else { return [] }
        let origin = CanvasPoint(x: x ?? frame.rect.origin.x, y: y ?? frame.rect.origin.y)
        guard origin.x.isFinite, origin.y.isFinite else { return [] }
        return CanvasMove.operations(movingFrame: id, to: CanvasRect(origin: origin, size: frame.rect.size), in: document)
    }

    private static func frame(_ id: CanvasFrameID, in document: CanvasDocument) -> CanvasFrame? {
        document.frames.first { $0.id == id }
    }
}
