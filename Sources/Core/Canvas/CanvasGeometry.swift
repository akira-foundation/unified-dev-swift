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
}
