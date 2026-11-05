import Foundation

public enum CanvasHitTest {
    public static func element(at point: CanvasPoint, in document: CanvasDocument, tolerance: Double = 0) -> CanvasElementID? {
        document.elements.last { contains($0, point: point, tolerance: max(tolerance, 0), in: document) }?.id
    }

    public static let frameLabelHeight = 20.0
    public static let frameLabelMinimumWidth = 44.0

    public static func frameLabel(
        at screen: CanvasPoint, in document: CanvasDocument, viewport: CanvasViewport, labelWidth: (CanvasFrame) -> Double
    ) -> CanvasFrameID? {
        document.frames.last { frame in
            let origin = viewport.toScreen(frame.rect.origin)
            let width = max(labelWidth(frame), frameLabelMinimumWidth)
            return screen.x >= origin.x && screen.x <= origin.x + width
                && screen.y >= origin.y - frameLabelHeight && screen.y < origin.y
        }?.id
    }

    public static func absoluteRect(of element: CanvasElement, in document: CanvasDocument) -> CanvasRect {
        guard let frameID = element.frameID, let frame = document.frames.first(where: { $0.id == frameID }) else {
            return element.rect
        }
        return CanvasRect(
            x: frame.rect.origin.x + element.rect.origin.x,
            y: frame.rect.origin.y + element.rect.origin.y,
            width: element.rect.size.width,
            height: element.rect.size.height
        )
    }

    private static func contains(_ element: CanvasElement, point: CanvasPoint, tolerance: Double, in document: CanvasDocument) -> Bool {
        let rect = absoluteRect(of: element, in: document)
        let centre = CanvasPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
        let radians = -element.style.rotation * .pi / 180
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        let local = CanvasPoint(x: centre.x + dx * cos(radians) - dy * sin(radians), y: centre.y + dx * sin(radians) + dy * cos(radians))
        switch element.kind {
        case .stroke(let stroke):
            return near(stroke, at: local, in: rect, tolerance: tolerance)
        case .shape(let shape):
            return near(shape, style: element.style, at: local, in: rect, tolerance: tolerance)
        case .text, .note, .image:
            return inside(rect, local)
        }
    }

    private static func inside(_ rect: CanvasRect, _ point: CanvasPoint) -> Bool {
        point.x >= rect.origin.x && point.x <= rect.origin.x + rect.size.width
            && point.y >= rect.origin.y && point.y <= rect.origin.y + rect.size.height
    }

    private static func near(_ stroke: CanvasStroke, at point: CanvasPoint, in rect: CanvasRect, tolerance: Double) -> Bool {
        let reach = max(stroke.width, 0) / 2 + tolerance
        let path = stroke.points.map { CanvasPoint(x: rect.origin.x + $0.x, y: rect.origin.y + $0.y) }
        guard let first = path.first else { return false }
        guard path.count > 1 else { return hypot(point.x - first.x, point.y - first.y) <= reach }
        return zip(path, path.dropFirst()).contains { CanvasSegment.distance(from: point, to: $0, $1) <= reach }
    }

    private static func near(
        _ shape: CanvasShape, style: CanvasStyle, at point: CanvasPoint, in rect: CanvasRect, tolerance: Double
    ) -> Bool {
        let reach = max(style.strokeWidth, 0) / 2 + tolerance
        switch shape.kind {
        case .line, .arrow:
            return CanvasShape.segments(of: shape.kind, in: rect).contains { CanvasSegment.distance(from: point, to: $0.0, $0.1) <= reach }
        case .rectangle, .ellipse:
            guard hasVisibleStroke(style), !isFilled(style) else {
                return shape.kind == .ellipse ? insideEllipse(rect, point) : inside(rect, point)
            }
            return outlineDistance(shape.kind, point: point, in: rect) <= reach
        }
    }

    private static func isFilled(_ style: CanvasStyle) -> Bool {
        visible(style.fill)
    }

    private static func hasVisibleStroke(_ style: CanvasStyle) -> Bool {
        style.strokeWidth > 0 && visible(style.stroke)
    }

    private static func visible(_ colour: String?) -> Bool {
        guard let colour, let parsed = CanvasColour(colour) else { return false }
        return parsed.alpha > 0
    }

    private static func insideEllipse(_ rect: CanvasRect, _ point: CanvasPoint) -> Bool {
        let a = rect.size.width / 2
        let b = rect.size.height / 2
        guard a > 0, b > 0 else { return inside(rect, point) }
        let x = (point.x - rect.origin.x - a) / a
        let y = (point.y - rect.origin.y - b) / b
        return x * x + y * y <= 1
    }

    private static func outlineDistance(_ kind: CanvasShape.Kind, point: CanvasPoint, in rect: CanvasRect) -> Double {
        let a = rect.size.width / 2
        let b = rect.size.height / 2
        let x = point.x - rect.origin.x - a
        let y = point.y - rect.origin.y - b
        if kind == .ellipse, a > 0, b > 0 {
            let value = (x / a) * (x / a) + (y / b) * (y / b) - 1
            let gradient = hypot(2 * x / (a * a), 2 * y / (b * b))
            return gradient > 0 ? abs(value) / gradient : min(a, b)
        }
        let outside = hypot(max(abs(x) - a, 0), max(abs(y) - b, 0))
        guard outside == 0 else { return outside }
        return min(a - abs(x), b - abs(y))
    }
}
