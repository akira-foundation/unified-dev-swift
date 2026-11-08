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

extension CanvasDocument {
    public func elements(in frame: CanvasFrameID) -> [CanvasElement] {
        elements.filter { $0.frameID == frame }
    }

    public var looseElementCount: Int {
        elements.filter { element in
            guard let id = element.frameID, let frame = frames.first(where: { $0.id == id }) else { return true }
            let inside = CanvasRect(x: 0, y: 0, width: frame.rect.size.width, height: frame.rect.size.height)
            return CanvasEditing.overlapArea(element.rect, inside) == 0
        }.count
    }

    public var strokePointCount: Int {
        elements.reduce(0) { total, element in
            guard case .stroke(let stroke) = element.kind else { return total }
            return total + stroke.points.count
        }
    }
}
