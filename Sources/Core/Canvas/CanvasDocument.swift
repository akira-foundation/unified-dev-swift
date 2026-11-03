import Foundation

public struct CanvasElementID: Identifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct CanvasFrameID: Identifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct CanvasCommentID: Identifier {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct CanvasFrame: Codable, Sendable, Hashable, Identifiable {
    public var id: CanvasFrameID
    public var name: String
    public var rect: CanvasRect
    public var fill: String
    public var revision: Int

    public init(id: CanvasFrameID = .new(), name: String, rect: CanvasRect, fill: String = "#FFFFFF", revision: Int = 0) {
        self.id = id
        self.name = name
        self.rect = rect
        self.fill = fill
        self.revision = revision
    }
}

public struct CanvasDocument: Codable, Sendable, Hashable {
    public static let currentVersion = 1

    public var version: Int
    public var frames: [CanvasFrame]
    public var elements: [CanvasElement]
    public var comments: [CanvasComment]

    public init(
        version: Int = CanvasDocument.currentVersion,
        frames: [CanvasFrame] = [],
        elements: [CanvasElement] = [],
        comments: [CanvasComment] = []
    ) {
        self.version = version
        self.frames = frames
        self.elements = elements
        self.comments = comments
    }
}
