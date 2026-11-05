import Foundation

public struct CanvasPenDraft: Sendable, Equatable {
    public static let toleranceCeiling = 8.0

    public private(set) var points: [CanvasPoint] = []
    public private(set) var wasCoarsened = false
    public private(set) var hasStopped = false
    public private(set) var isRefused = false

    public init() {}

    public var isEmpty: Bool { points.isEmpty }

    public mutating func append(_ point: CanvasPoint, tolerance: Double) {
        if isRefused { self = CanvasPenDraft() }
        guard !hasStopped else { return }
        points.append(point)
        guard points.count > CanvasStrokeBuilder.inputLimit else { return }
        let target = CanvasStrokeBuilder.inputLimit / 2
        let cut = CanvasStrokeBuilder.reduction(
            of: points, tolerance: tolerance, limit: target, ceiling: tolerance * Self.toleranceCeiling
        )
        guard cut.points.count <= target else {
            points.removeLast()
            hasStopped = true
            return
        }
        points = cut.points
        wasCoarsened = wasCoarsened || cut.coarsened
    }

    public mutating func refused() {
        isRefused = true
    }

    public mutating func noticeDismissed() {
        if isRefused { self = CanvasPenDraft() }
    }

    public func element(width: Double, colour: String, tolerance: Double, in document: CanvasDocument) -> CanvasElement? {
        CanvasStrokeBuilder.element(drawing: points, width: width, colour: colour, tolerance: tolerance, in: document)
    }
}
