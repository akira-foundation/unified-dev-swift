import Foundation

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

    public static func resized(
        _ rect: CanvasRect, rotation: Double, handle: CanvasResizeHandle, to point: CanvasPoint, keepingAspect: Bool
    ) -> CanvasRect {
        guard rotation != 0 else { return resized(rect, handle: handle, to: point, keepingAspect: keepingAspect) }
        let middle = centre(of: rect)
        let anchor = handle.opposite.position(in: rect)
        let anchorOnScreen = rotated(anchor, about: middle, by: rotation)
        let offset = rotated(
            CanvasPoint(x: point.x - anchorOnScreen.x, y: point.y - anchorOnScreen.y), about: CanvasPoint(x: 0, y: 0), by: -rotation
        )
        let local = resized(
            rect, handle: handle, to: CanvasPoint(x: anchor.x + offset.x, y: anchor.y + offset.y), keepingAspect: keepingAspect
        )
        let newCentre = centre(of: local)
        let drifted = rotated(anchor, about: newCentre, by: rotation)
        return CanvasRect(
            x: local.origin.x + anchorOnScreen.x - drifted.x,
            y: local.origin.y + anchorOnScreen.y - drifted.y,
            width: local.size.width,
            height: local.size.height
        )
    }

    public static func handlePoint(_ handle: CanvasResizeHandle, of rect: CanvasRect, rotation: Double) -> CanvasPoint {
        rotated(handle.position(in: rect), about: centre(of: rect), by: rotation)
    }

    static func centre(of rect: CanvasRect) -> CanvasPoint {
        CanvasPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
    }

    static func rotated(_ point: CanvasPoint, about centre: CanvasPoint, by degrees: Double) -> CanvasPoint {
        let radians = degrees * .pi / 180
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        return CanvasPoint(
            x: centre.x + dx * cos(radians) - dy * sin(radians),
            y: centre.y + dx * sin(radians) + dy * cos(radians)
        )
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

extension CanvasResizeHandle {
    var opposite: CanvasResizeHandle {
        switch self {
        case .topLeft: .bottomRight
        case .top: .bottom
        case .topRight: .bottomLeft
        case .right: .left
        case .bottomRight: .topLeft
        case .bottom: .top
        case .bottomLeft: .topRight
        case .left: .right
        }
    }

    func position(in rect: CanvasRect) -> CanvasPoint {
        let x = movesLeft ? rect.origin.x : movesRight ? rect.origin.x + rect.size.width : rect.origin.x + rect.size.width / 2
        let y = movesTop ? rect.origin.y : movesBottom ? rect.origin.y + rect.size.height : rect.origin.y + rect.size.height / 2
        return CanvasPoint(x: x, y: y)
    }
}
