public enum CanvasResizeHandle: CaseIterable, Sendable, Hashable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

public enum CanvasResize {
    public static let minimumSide = 1.0

    public static func resized(
        _ rect: CanvasRect, handle: CanvasResizeHandle, to point: CanvasPoint, keepingAspect: Bool
    ) -> CanvasRect {
        var left = rect.origin.x
        var top = rect.origin.y
        var right = left + rect.size.width
        var bottom = top + rect.size.height
        if handle.movesLeft { left = min(point.x, right - minimumSide) }
        if handle.movesRight { right = max(point.x, left + minimumSide) }
        if handle.movesTop { top = min(point.y, bottom - minimumSide) }
        if handle.movesBottom { bottom = max(point.y, top + minimumSide) }
        let resized = CanvasRect(x: left, y: top, width: right - left, height: bottom - top)
        guard keepingAspect, rect.size.width > 0, rect.size.height > 0 else { return resized }
        return fitted(resized, toAspectOf: rect, handle: handle)
    }

    private static func fitted(_ resized: CanvasRect, toAspectOf original: CanvasRect, handle: CanvasResizeHandle) -> CanvasRect {
        let ratio = original.size.width / original.size.height
        var width = resized.size.width
        var height = resized.size.height
        switch (handle.movesHorizontally, handle.movesVertically) {
        case (true, true):
            let scale = max(width / original.size.width, height / original.size.height)
            width = max(original.size.width * scale, minimumSide)
            height = max(original.size.height * scale, minimumSide)
        case (true, false):
            height = max(width / ratio, minimumSide)
        default:
            width = max(height * ratio, minimumSide)
        }
        let x = handle.movesLeft ? resized.origin.x + resized.size.width - width
            : handle.movesRight ? resized.origin.x
            : original.origin.x + (original.size.width - width) / 2
        let y = handle.movesTop ? resized.origin.y + resized.size.height - height
            : handle.movesBottom ? resized.origin.y
            : original.origin.y + (original.size.height - height) / 2
        return CanvasRect(x: x, y: y, width: width, height: height)
    }
}

extension CanvasResizeHandle {
    var movesLeft: Bool { self == .topLeft || self == .left || self == .bottomLeft }
    var movesRight: Bool { self == .topRight || self == .right || self == .bottomRight }
    var movesTop: Bool { self == .topLeft || self == .top || self == .topRight }
    var movesBottom: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }
    var movesHorizontally: Bool { movesLeft || movesRight }
    var movesVertically: Bool { movesTop || movesBottom }
}
