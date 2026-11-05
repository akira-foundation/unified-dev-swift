import Foundation

public struct CanvasImageNeed: Sendable, Hashable {
    public static let longestSideCeiling = 4_096

    public let width: Double
    public let height: Double
    public let pixelsPerPoint: Double

    public init(width: Double, height: Double, pixelsPerPoint: Double) {
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.pixelsPerPoint = Self.nextPowerOfTwo(atLeast: max(pixelsPerPoint, 1))
    }

    func longestSide(ofSource source: CanvasImagePixelSize?) -> Int {
        guard let source, source.width > 0, source.height > 0 else { return Self.rounded(max(width, height) * pixelsPerPoint) }
        let filling = max(width / Double(source.width), height / Double(source.height)) * pixelsPerPoint
        let wanted = Self.rounded(Double(source.longestSide) * filling)
        return min(wanted, source.longestSide)
    }

    private static func rounded(_ pixels: Double) -> Int {
        Int(min(nextPowerOfTwo(atLeast: pixels), Double(longestSideCeiling)))
    }

    private static func nextPowerOfTwo(atLeast value: Double) -> Double {
        pow(2, ceil(log2(max(value, 1))))
    }
}
