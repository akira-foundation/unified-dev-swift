import Foundation
@testable import Core

enum CanvasDeviation {
    static func max(of original: [CanvasPoint], from polyline: [CanvasPoint]) -> Double {
        guard polyline.count > 1 else {
            return original.map { point in polyline.first.map { hypot(point.x - $0.x, point.y - $0.y) } ?? 0 }.max() ?? 0
        }
        guard let first = original.first, same(first, polyline[0]) else { return .infinity }
        var reached = 0
        var worst = 0.0
        for point in original {
            let start = Swift.min(reached, polyline.count - 2)
            worst = Swift.max(worst, CanvasSegment.distance(from: point, to: polyline[start], polyline[start + 1]))
            if reached < polyline.count - 1, same(point, polyline[reached + 1]) { reached += 1 }
        }
        return reached == polyline.count - 1 ? worst : .infinity
    }

    static func zigzag(_ count: Int, amplitude: Double) -> [CanvasPoint] {
        (0..<count).map { CanvasPoint(x: Double($0), y: Double(($0 * 37) % 17) / 16 * amplitude) }
    }

    static func cursive(_ count: Int) -> [CanvasPoint] {
        (0..<count).map { CanvasPoint(x: Double($0) * 0.5, y: 30 * sin(Double($0) / 20) + 5 * sin(Double($0) / 3)) }
    }

    static func loopedCursive(_ count: Int) -> [CanvasPoint] {
        (0..<count).map {
            let turn = Double($0) / 2.3
            return CanvasPoint(x: Double($0) * 0.003 + 30 * sin(turn), y: 30 * cos(turn))
        }
    }

    private static func same(_ first: CanvasPoint, _ second: CanvasPoint) -> Bool {
        hypot(first.x - second.x, first.y - second.y) < 1e-6
    }
}
