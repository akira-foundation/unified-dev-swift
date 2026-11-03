import Foundation

public struct CanvasPoint: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CanvasSize: Codable, Sendable, Hashable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct CanvasRect: Codable, Sendable, Hashable {
    public var origin: CanvasPoint
    public var size: CanvasSize

    public init(origin: CanvasPoint, size: CanvasSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: CanvasPoint(x: x, y: y), size: CanvasSize(width: width, height: height))
    }

    public static func union(of rects: [CanvasRect]) -> CanvasRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { union, rect in
            let minX = min(union.origin.x, rect.origin.x)
            let minY = min(union.origin.y, rect.origin.y)
            let maxX = max(union.origin.x + union.size.width, rect.origin.x + rect.size.width)
            let maxY = max(union.origin.y + union.size.height, rect.origin.y + rect.size.height)
            return CanvasRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}
