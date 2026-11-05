import Foundation

public enum CanvasFrameSize {
    public static let minimum = 1.0
    public static let maximum = 8_192.0

    public static func clamped(_ size: CanvasSize) -> CanvasSize {
        CanvasSize(
            width: min(max(size.width, minimum), maximum),
            height: min(max(size.height, minimum), maximum)
        )
    }

    public static func operations(resizing id: CanvasFrameID, to size: CanvasSize, in document: CanvasDocument) -> [CanvasOperation] {
        guard let frame = document.frames.first(where: { $0.id == id }) else { return [] }
        let target = clamped(size)
        guard target != frame.rect.size else { return [] }
        return [.updateFrame(id, expectedRevision: nil, CanvasFramePatch(rect: CanvasRect(origin: frame.rect.origin, size: target)))]
    }
}
