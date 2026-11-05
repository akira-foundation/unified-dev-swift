import Foundation

public struct CanvasRevisionEntry<ID: Identifier>: Sendable, Equatable {
    public var id: ID
    public var revision: Int

    public init(id: ID, revision: Int) {
        self.id = id
        self.revision = revision
    }
}

public struct CanvasChangeSummary: Sendable, Equatable {
    public var frames: [CanvasRevisionEntry<CanvasFrameID>]
    public var elements: [CanvasRevisionEntry<CanvasElementID>]
    public var deletedFrames: [CanvasFrameID]
    public var deletedElements: [CanvasElementID]

    public init(
        frames: [CanvasRevisionEntry<CanvasFrameID>] = [], elements: [CanvasRevisionEntry<CanvasElementID>] = [],
        deletedFrames: [CanvasFrameID] = [], deletedElements: [CanvasElementID] = []
    ) {
        self.frames = frames
        self.elements = elements
        self.deletedFrames = deletedFrames
        self.deletedElements = deletedElements
    }

    public init(from before: CanvasDocument, to after: CanvasDocument) {
        let framesBefore = Dictionary(before.frames.map { ($0.id, $0.revision) }, uniquingKeysWith: { first, _ in first })
        let elementsBefore = Dictionary(before.elements.map { ($0.id, $0.revision) }, uniquingKeysWith: { first, _ in first })
        frames = after.frames.filter { framesBefore[$0.id] != $0.revision }
            .map { CanvasRevisionEntry(id: $0.id, revision: $0.revision) }
        elements = after.elements.filter { elementsBefore[$0.id] != $0.revision }
            .map { CanvasRevisionEntry(id: $0.id, revision: $0.revision) }
        let framesAfter = Set(after.frames.map(\.id))
        let elementsAfter = Set(after.elements.map(\.id))
        deletedFrames = before.frames.map(\.id).filter { !framesAfter.contains($0) }
        deletedElements = before.elements.map(\.id).filter { !elementsAfter.contains($0) }
    }
}
