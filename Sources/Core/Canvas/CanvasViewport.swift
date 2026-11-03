import Foundation

public struct CanvasViewport: Sendable, Hashable {
    public static let zoomRange = 0.1...4.0
    public static let fittingMargin = 0.9

    public var zoom: Double
    public var offset: CanvasPoint

    public init(zoom: Double = 1, offset: CanvasPoint = CanvasPoint(x: 0, y: 0)) {
        self.zoom = Self.clamped(zoom)
        self.offset = offset
    }

    public func toCanvas(_ screen: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: (screen.x - offset.x) / zoom, y: (screen.y - offset.y) / zoom)
    }

    public func toScreen(_ canvas: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: canvas.x * zoom + offset.x, y: canvas.y * zoom + offset.y)
    }

    public mutating func zoom(by factor: Double, around screen: CanvasPoint) {
        let anchor = toCanvas(screen)
        zoom = Self.clamped(zoom * factor)
        offset = CanvasPoint(x: screen.x - anchor.x * zoom, y: screen.y - anchor.y * zoom)
    }

    public static func fitting(_ rect: CanvasRect, in size: CanvasSize) -> CanvasViewport {
        guard rect.size.width > 0, rect.size.height > 0, size.width > 0, size.height > 0 else {
            return CanvasViewport()
        }
        let scale = min(size.width / rect.size.width, size.height / rect.size.height) * fittingMargin
        var viewport = CanvasViewport(zoom: scale)
        let centre = CanvasPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        viewport.offset = CanvasPoint(
            x: size.width / 2 - centre.x * viewport.zoom,
            y: size.height / 2 - centre.y * viewport.zoom
        )
        return viewport
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
    }
}
