import Foundation

public struct CanvasPlayback: Sendable, Equatable {
    public private(set) var frames: [CanvasFrame]
    public private(set) var current: Int

    public init(frames: [CanvasFrame], startingAt first: CanvasFrameID? = nil) {
        let ordered = CanvasExportNames.slideOrder(frames)
        self.frames = ordered
        current = first.flatMap { id in ordered.firstIndex { $0.id == id } } ?? 0
    }

    public var frame: CanvasFrame? {
        frames.indices.contains(current) ? frames[current] : nil
    }

    public var count: Int { frames.count }
    public var isAtStart: Bool { current <= 0 }
    public var isAtEnd: Bool { current >= frames.count - 1 }

    public mutating func next() {
        current = min(current + 1, max(frames.count - 1, 0))
    }

    public mutating func previous() {
        current = max(current - 1, 0)
    }

    public mutating func update(frames updated: [CanvasFrame]) {
        let following = frame?.id
        let ordered = CanvasExportNames.slideOrder(updated)
        frames = ordered
        if let following, let index = ordered.firstIndex(where: { $0.id == following }) {
            current = index
        } else {
            current = min(max(current, 0), max(ordered.count - 1, 0))
        }
    }
}
