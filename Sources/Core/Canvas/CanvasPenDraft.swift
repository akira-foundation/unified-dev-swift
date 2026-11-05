import Foundation

public struct CanvasPenDraft: Sendable, Equatable {
    public private(set) var points: [CanvasPoint] = []
    public private(set) var wasCoarsened = false
    public private(set) var deviationBound = 0.0

    public init() {}

    public var isEmpty: Bool { points.isEmpty }

    public mutating func append(_ point: CanvasPoint, tolerance: Double) {
        points.append(point)
        guard points.count > CanvasStrokeBuilder.inputLimit else { return }
        let cut = CanvasStrokeBuilder.reduction(of: points, tolerance: tolerance, limit: CanvasStrokeBuilder.inputLimit / 2)
        points = cut.points
        wasCoarsened = wasCoarsened || cut.coarsened
        deviationBound += cut.tolerance
    }

    public func element(width: Double, colour: String, tolerance: Double, in document: CanvasDocument) -> CanvasElement? {
        CanvasStrokeBuilder.element(drawing: points, width: width, colour: colour, tolerance: tolerance, in: document)
    }
}
