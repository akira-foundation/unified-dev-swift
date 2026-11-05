import Foundation

public enum CanvasAuthor: Sendable, Equatable {
    case owner, agent
}

public struct CanvasShadowPatch: Codable, Sendable, Hashable {
    public var offsetX: Double?
    public var offsetY: Double?
    public var radius: Double?
    public var colour: String?

    public init(offsetX: Double? = nil, offsetY: Double? = nil, radius: Double? = nil, colour: String? = nil) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.radius = radius
        self.colour = colour
    }
}

public struct CanvasStylePatch: Codable, Sendable, Hashable {
    public var fill: String?
    public var clearFill: Bool?
    public var stroke: String?
    public var clearStroke: Bool?
    public var strokeWidth: Double?
    public var cornerRadius: Double?
    public var opacity: Double?
    public var rotation: Double?
    public var shadow: CanvasShadowPatch?
    public var clearShadow: Bool?

    public init(
        fill: String? = nil,
        clearFill: Bool? = nil,
        stroke: String? = nil,
        clearStroke: Bool? = nil,
        strokeWidth: Double? = nil,
        cornerRadius: Double? = nil,
        opacity: Double? = nil,
        rotation: Double? = nil,
        shadow: CanvasShadowPatch? = nil,
        clearShadow: Bool? = nil
    ) {
        self.fill = fill
        self.clearFill = clearFill
        self.stroke = stroke
        self.clearStroke = clearStroke
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.rotation = rotation
        self.shadow = shadow
        self.clearShadow = clearShadow
    }

    func applied(to style: CanvasStyle) -> CanvasStyle {
        var result = style
        if clearFill == true { result.fill = nil }
        if let fill { result.fill = fill }
        if clearStroke == true { result.stroke = nil }
        if let stroke { result.stroke = stroke }
        if let strokeWidth { result.strokeWidth = strokeWidth }
        if let cornerRadius { result.cornerRadius = cornerRadius }
        if let opacity { result.opacity = opacity }
        if let rotation { result.rotation = rotation }
        if clearShadow == true { result.shadow = nil }
        if let shadow {
            var merged = result.shadow ?? CanvasShadow(offsetX: 0, offsetY: 0, radius: 0, colour: "#00000066")
            if let value = shadow.offsetX { merged.offsetX = value }
            if let value = shadow.offsetY { merged.offsetY = value }
            if let value = shadow.radius { merged.radius = value }
            if let value = shadow.colour { merged.colour = value }
            result.shadow = merged
        }
        return result
    }
}

public struct CanvasElementPatch: Codable, Sendable, Hashable {
    public var frameID: CanvasFrameID?
    public var clearFrame: Bool?
    public var rect: CanvasRect?
    public var style: CanvasStylePatch?
    public var kind: CanvasElement.Kind?

    public init(
        frameID: CanvasFrameID? = nil,
        clearFrame: Bool? = nil,
        rect: CanvasRect? = nil,
        style: CanvasStylePatch? = nil,
        kind: CanvasElement.Kind? = nil
    ) {
        self.frameID = frameID
        self.clearFrame = clearFrame
        self.rect = rect
        self.style = style
        self.kind = kind
    }

    func applied(to element: CanvasElement) -> CanvasElement {
        var result = element
        if clearFrame == true { result.frameID = nil }
        if let frameID { result.frameID = frameID }
        if let rect { result.rect = rect }
        if let style { result.style = style.applied(to: result.style) }
        if let kind { result.kind = kind }
        return result
    }
}

public struct CanvasFramePatch: Codable, Sendable, Hashable {
    public var name: String?
    public var rect: CanvasRect?
    public var fill: String?

    public init(name: String? = nil, rect: CanvasRect? = nil, fill: String? = nil) {
        self.name = name
        self.rect = rect
        self.fill = fill
    }

    func applied(to frame: CanvasFrame) -> CanvasFrame {
        var result = frame
        if let name { result.name = name }
        if let rect { result.rect = rect }
        if let fill { result.fill = fill }
        return result
    }
}

public enum CanvasOperation: Sendable, Hashable {
    case addFrame(CanvasFrame)
    case updateFrame(CanvasFrameID, expectedRevision: Int?, CanvasFramePatch)
    case deleteFrame(CanvasFrameID, expectedRevision: Int?)
    case addElement(CanvasElement)
    case updateElement(CanvasElementID, expectedRevision: Int?, CanvasElementPatch)
    case deleteElement(CanvasElementID, expectedRevision: Int?)
    case reorder(CanvasElementID, toIndex: Int)
}

extension CanvasOperation {
    public enum Name: String, CaseIterable, Sendable {
        case addFrame, updateFrame, deleteFrame, addElement, updateElement, deleteElement, reorder
    }

    public var name: Name {
        switch self {
        case .addFrame: .addFrame
        case .updateFrame: .updateFrame
        case .deleteFrame: .deleteFrame
        case .addElement: .addElement
        case .updateElement: .updateElement
        case .deleteElement: .deleteElement
        case .reorder: .reorder
        }
    }
}

extension CanvasOperation: Codable {
    private enum Key: String, CodingKey {
        case op, id, expectedRevision, frame, element, patch, toIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let raw = try container.decode(String.self, forKey: .op)
        guard let name = Name(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .op, in: container, debugDescription: "Unknown canvas operation '\(raw)'"
            )
        }
        let revision = try container.decodeIfPresent(Int.self, forKey: .expectedRevision)
        switch name {
        case .addFrame:
            self = .addFrame(try container.decode(CanvasFrame.self, forKey: .frame))
        case .updateFrame:
            self = .updateFrame(
                try container.decode(CanvasFrameID.self, forKey: .id),
                expectedRevision: revision,
                try container.decode(CanvasFramePatch.self, forKey: .patch)
            )
        case .deleteFrame:
            self = .deleteFrame(try container.decode(CanvasFrameID.self, forKey: .id), expectedRevision: revision)
        case .addElement:
            self = .addElement(try container.decode(CanvasElement.self, forKey: .element))
        case .updateElement:
            self = .updateElement(
                try container.decode(CanvasElementID.self, forKey: .id),
                expectedRevision: revision,
                try container.decode(CanvasElementPatch.self, forKey: .patch)
            )
        case .deleteElement:
            self = .deleteElement(try container.decode(CanvasElementID.self, forKey: .id), expectedRevision: revision)
        case .reorder:
            self = .reorder(
                try container.decode(CanvasElementID.self, forKey: .id),
                toIndex: try container.decode(Int.self, forKey: .toIndex)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(name.rawValue, forKey: .op)
        switch self {
        case .addFrame(let frame):
            try container.encode(frame, forKey: .frame)
        case .updateFrame(let id, let revision, let patch):
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(revision, forKey: .expectedRevision)
            try container.encode(patch, forKey: .patch)
        case .deleteFrame(let id, let revision):
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(revision, forKey: .expectedRevision)
        case .addElement(let element):
            try container.encode(element, forKey: .element)
        case .updateElement(let id, let revision, let patch):
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(revision, forKey: .expectedRevision)
            try container.encode(patch, forKey: .patch)
        case .deleteElement(let id, let revision):
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(revision, forKey: .expectedRevision)
        case .reorder(let id, let index):
            try container.encode(id, forKey: .id)
            try container.encode(index, forKey: .toIndex)
        }
    }
}

public struct CanvasConflict: Sendable, Equatable {
    public enum Current: Sendable, Equatable {
        case element(CanvasElement)
        case frame(CanvasFrame)
    }

    public var target: String
    public var revision: Int
    public var current: Current

    public init(target: String, revision: Int, current: Current) {
        self.target = target
        self.revision = revision
        self.current = current
    }
}

public enum CanvasEditOutcome: Sendable, Equatable {
    case applied(CanvasDocument)
    case conflict([CanvasConflict])
    case invalid(String)
}
