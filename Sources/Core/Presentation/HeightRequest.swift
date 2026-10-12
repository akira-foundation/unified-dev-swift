import CoreGraphics

public struct HeightRequest: Equatable, Sendable, Codable {
    public static let ceiling: CGFloat = 100_000

    public var width: CGFloat

    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    public var isBounded: Bool {
        height.isFinite && height >= 0 && height < Self.ceiling
    }

    public var json: JSONValue {
        .object(["width": .number(Double(width)), "height": .number(Double(height))])
    }
}

public struct HeightSweep: Equatable, Sendable, Codable {
    public static let tolerance: CGFloat = 1

    public static let referenceWidth: CGFloat = 4_000

    public var reference: HeightRequest

    public var atHostWidths: [HeightRequest]

    public init(reference: HeightRequest, atHostWidths: [HeightRequest]) {
        self.reference = reference
        self.atHostWidths = atHostWidths
    }

    public var every: [HeightRequest] { [reference] + atHostWidths }

    public var unbounded: [HeightRequest] { every.filter { !$0.isBounded } }

    public var isBounded: Bool { unbounded.isEmpty }

    public var json: JSONValue {
        .object([
            "reference": reference.json,
            "atHostWidths": .array(atHostWidths.map(\.json)),
            "bounded": .bool(isBounded),
        ])
    }
}

public struct HeightComparison: Equatable, Sendable, Codable {
    public var saying: HeightSweep

    public var shortened: HeightSweep

    public init(saying: HeightSweep, shortened: HeightSweep) {
        self.saying = saying
        self.shortened = shortened
    }

    public var isBounded: Bool { saying.isBounded && shortened.isBounded }

    public var narrows: Bool {
        saying.atHostWidths.contains { $0.height > saying.reference.height + HeightSweep.tolerance }
    }

    public var lengthens: Bool {
        zip(saying.atHostWidths, shortened.atHostWidths)
            .contains { $0.height > $1.height + HeightSweep.tolerance }
    }

    public var wraps: Bool { !isBounded || narrows || lengthens }

    public var wasStaged: Bool {
        saying.reference.height >= Self.leastStagedHeight
    }

    public static let leastStagedHeight: CGFloat = 8

    public var json: JSONValue {
        .object([
            "saying": saying.json,
            "shortened": shortened.json,
            "narrows": .bool(narrows),
            "lengthens": .bool(lengthens),
            "wraps": .bool(wraps),
            "staged": .bool(wasStaged),
        ])
    }
}
