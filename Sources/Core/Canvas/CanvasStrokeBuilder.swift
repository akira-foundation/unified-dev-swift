import Foundation

public struct CanvasReduction: Sendable, Equatable {
    public var points: [CanvasPoint]
    public var tolerance: Double
    public var coarsened: Bool
}

public enum CanvasStrokeBuilder {
    public static let maximumPoints = 10_000
    public static let inputLimit = 4_096
    public static let maximumDocumentPoints = 200_000

    public static func reduction(of points: [CanvasPoint], tolerance: Double, limit: Int) -> CanvasReduction {
        let distinct = deduplicated(points)
        guard distinct.count > 2, tolerance.isFinite, tolerance >= 0, limit >= 2 else {
            return CanvasReduction(points: distinct, tolerance: tolerance, coarsened: false)
        }
        var reach = tolerance
        var kept = douglasPeucker(distinct, tolerance: reach)
        while kept.count > limit {
            reach = max(reach, 0.01) * 2
            kept = douglasPeucker(distinct, tolerance: reach)
        }
        return CanvasReduction(points: kept, tolerance: reach, coarsened: reach > tolerance)
    }

    public static func simplified(_ points: [CanvasPoint], tolerance: Double) -> [CanvasPoint] {
        reduction(of: points, tolerance: tolerance, limit: inputLimit).points
    }

    public static func bounds(_ stroke: CanvasStroke) -> CanvasRect {
        let pad = padding(of: stroke.width)
        guard let first = stroke.points.first else { return CanvasRect(x: 0, y: 0, width: pad * 2, height: pad * 2) }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in stroke.points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CanvasRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
    }

    public static func element(
        drawing points: [CanvasPoint], width: Double, colour: String, tolerance: Double, in document: CanvasDocument
    ) -> CanvasElement? {
        let kept = simplified(points, tolerance: tolerance)
        guard !kept.isEmpty else { return nil }
        let frame = CanvasEditing.frame(holding: points, in: document)
        let origin = frame?.rect.origin ?? CanvasPoint(x: 0, y: 0)
        let local = kept.map { CanvasPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        let box = bounds(CanvasStroke(points: local, width: width, colour: colour))
        let relative = local.map { CanvasPoint(x: $0.x - box.origin.x, y: $0.y - box.origin.y) }
        return CanvasElement(
            frameID: frame?.id,
            rect: box,
            kind: .stroke(CanvasStroke(points: relative, width: width, colour: colour))
        )
    }

    public static func resized(_ stroke: CanvasStroke, from old: CanvasSize, to new: CanvasSize) -> CanvasStroke {
        let pad = padding(of: stroke.width)
        guard let first = stroke.points.first else { return stroke }
        let low = stroke.points.reduce(first) { CanvasPoint(x: min($0.x, $1.x), y: min($0.y, $1.y)) }
        let high = stroke.points.reduce(first) { CanvasPoint(x: max($0.x, $1.x), y: max($0.y, $1.y)) }
        func scaled(_ value: Double, _ from: Double, _ to: Double, _ side: Double) -> Double {
            let inner = side - pad * 2
            guard to > from, inner > 0 else { return side / 2 }
            return pad + (value - from) * inner / (to - from)
        }
        var result = stroke
        result.points = stroke.points.map {
            CanvasPoint(x: scaled($0.x, low.x, high.x, new.width), y: scaled($0.y, low.y, high.y, new.height))
        }
        return result
    }

    public static func reframed(_ element: CanvasElement, with stroke: CanvasStroke) -> CanvasElementPatch {
        let box = bounds(stroke)
        let moved = CanvasStroke(
            points: stroke.points.map { CanvasPoint(x: $0.x - box.origin.x, y: $0.y - box.origin.y) },
            width: stroke.width, colour: stroke.colour
        )
        let rect = CanvasRect(
            x: element.rect.origin.x + box.origin.x, y: element.rect.origin.y + box.origin.y,
            width: box.size.width, height: box.size.height
        )
        return CanvasElementPatch(rect: rect, kind: .stroke(moved))
    }

    private static func padding(of width: Double) -> Double {
        max(width / 2, 0.5)
    }

    private static func douglasPeucker(_ points: [CanvasPoint], tolerance: Double) -> [CanvasPoint] {
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var pending = [(0, points.count - 1)]
        while let (first, last) = pending.popLast() {
            guard last - first > 1 else { continue }
            var farthest = first
            var distance = 0.0
            let middle = Double(first + last) / 2
            for index in (first + 1)..<last {
                let candidate = CanvasSegment.distance(from: points[index], to: points[first], points[last])
                let tied = abs(candidate - distance) <= 1e-9 * max(distance, 1)
                if candidate > distance + 1e-9 * max(distance, 1) || (tied && abs(Double(index) - middle) < abs(Double(farthest) - middle)) {
                    distance = max(distance, candidate)
                    farthest = index
                }
            }
            guard distance > tolerance else { continue }
            keep[farthest] = true
            pending.append((first, farthest))
            pending.append((farthest, last))
        }
        return zip(points, keep).filter(\.1).map(\.0)
    }

    private static func deduplicated(_ points: [CanvasPoint]) -> [CanvasPoint] {
        var result: [CanvasPoint] = []
        for point in points where result.last != point { result.append(point) }
        return result
    }
}

enum CanvasSegment {
    static func distance(from point: CanvasPoint, to start: CanvasPoint, _ end: CanvasPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let along = min(max(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared, 0), 1)
        return hypot(point.x - (start.x + along * dx), point.y - (start.y + along * dy))
    }
}
