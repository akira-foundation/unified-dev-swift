import Foundation

public struct CanvasShadow: Codable, Sendable, Hashable {
    public var offsetX: Double
    public var offsetY: Double
    public var radius: Double
    public var colour: String

    public init(offsetX: Double, offsetY: Double, radius: Double, colour: String) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.radius = radius
        self.colour = colour
    }
}

public struct CanvasStyle: Codable, Sendable, Hashable {
    public var fill: String?
    public var stroke: String?
    public var strokeWidth: Double
    public var cornerRadius: Double
    public var opacity: Double
    public var rotation: Double
    public var shadow: CanvasShadow?

    public init(
        fill: String? = nil,
        stroke: String? = nil,
        strokeWidth: Double = 0,
        cornerRadius: Double = 0,
        opacity: Double = 1,
        rotation: Double = 0,
        shadow: CanvasShadow? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.rotation = rotation
        self.shadow = shadow
    }
}

public struct CanvasTextRun: Codable, Sendable, Hashable {
    public var text: String
    public var fontName: String
    public var size: Double
    public var weight: Double
    public var colour: String

    public init(text: String, fontName: String, size: Double, weight: Double, colour: String) {
        self.text = text
        self.fontName = fontName
        self.size = size
        self.weight = weight
        self.colour = colour
    }
}

public struct CanvasText: Codable, Sendable, Hashable {
    public enum Alignment: String, Codable, Sendable, Hashable {
        case leading, centre, trailing
    }

    public var runs: [CanvasTextRun]
    public var alignment: Alignment

    public init(runs: [CanvasTextRun], alignment: Alignment = .leading) {
        self.runs = runs
        self.alignment = alignment
    }
}

public struct CanvasShape: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable, Hashable, CaseIterable {
        case rectangle, ellipse, line, arrow
    }

    public var kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public static let maximumHeadLength = 24.0

    public static func headLength(forWidth width: Double) -> Double {
        min(width, maximumHeadLength)
    }

    public static func segments(of kind: Kind, in rect: CanvasRect) -> [(CanvasPoint, CanvasPoint)] {
        let minX = rect.origin.x
        let maxX = rect.origin.x + rect.size.width
        let middle = rect.origin.y + rect.size.height / 2
        let tip = CanvasPoint(x: maxX, y: middle)
        var result = [(CanvasPoint(x: minX, y: middle), tip)]
        if kind == .arrow {
            let head = headLength(forWidth: rect.size.width)
            result.append((CanvasPoint(x: maxX - head, y: middle - head / 2), tip))
            result.append((CanvasPoint(x: maxX - head, y: middle + head / 2), tip))
        }
        return result
    }
}

public struct CanvasStroke: Codable, Sendable, Hashable {
    public var points: [CanvasPoint]
    public var width: Double
    public var colour: String

    public init(points: [CanvasPoint], width: Double, colour: String) {
        self.points = points
        self.width = width
        self.colour = colour
    }
}

public struct CanvasElement: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: Codable, Sendable, Hashable {
        case text(CanvasText)
        case image(path: String)
        case shape(CanvasShape)
        case note(CanvasText)
        case stroke(CanvasStroke)
    }

    public var id: CanvasElementID
    public var frameID: CanvasFrameID?
    public var revision: Int
    public var rect: CanvasRect
    public var style: CanvasStyle
    public var kind: Kind

    public init(
        id: CanvasElementID = .new(),
        frameID: CanvasFrameID? = nil,
        revision: Int = 0,
        rect: CanvasRect,
        style: CanvasStyle = CanvasStyle(),
        kind: Kind
    ) {
        self.id = id
        self.frameID = frameID
        self.revision = revision
        self.rect = rect
        self.style = style
        self.kind = kind
    }
}
