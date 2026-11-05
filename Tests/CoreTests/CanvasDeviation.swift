import Foundation
@testable import Core

enum CanvasDeviation {
    static func max(of original: [CanvasPoint], from polyline: [CanvasPoint]) -> Double {
        guard polyline.count > 1 else {
            return original.map { point in polyline.first.map { hypot(point.x - $0.x, point.y - $0.y) } ?? 0 }.max() ?? 0
        }
        var worst = 0.0
        for point in original {
            var nearest = Double.greatestFiniteMagnitude
            for index in 1..<polyline.count {
                nearest = min(nearest, CanvasSegment.distance(from: point, to: polyline[index - 1], polyline[index]))
                if nearest == 0 { break }
            }
            worst = Swift.max(worst, nearest)
        }
        return worst
    }

    static func zigzag(_ count: Int, amplitude: Double) -> [CanvasPoint] {
        (0..<count).map { CanvasPoint(x: Double($0), y: Double(($0 * 37) % 17) / 16 * amplitude) }
    }

    static func cursive(_ count: Int) -> [CanvasPoint] {
        (0..<count).map { CanvasPoint(x: Double($0) * 0.5, y: 30 * sin(Double($0) / 20) + 5 * sin(Double($0) / 3)) }
    }
}
