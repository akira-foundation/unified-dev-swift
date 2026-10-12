public struct WindowInk: Equatable, Sendable, Codable {
    public enum Verdict: String, Equatable, Sendable, CaseIterable, Codable {
        case drew
        case stoppedDrawing
        case unreadable
    }

    public static let share = 0.75

    public static let unread = -1.0

    public var onArrival: Double

    public var afterRedraw: Double

    public init(onArrival: Double, afterRedraw: Double) {
        self.onArrival = onArrival
        self.afterRedraw = afterRedraw
    }

    public static let unreadable = WindowInk(onArrival: unread, afterRedraw: unread)

    public var isReadable: Bool { onArrival >= 0 && afterRedraw >= 0 }

    public var carriesSomething: Bool { onArrival > 0 && afterRedraw > 0 }

    public var lowest: Double { min(onArrival, afterRedraw) }

    public func verdict(against baseline: WindowInk) -> Verdict {
        guard baseline.carriesSomething, isReadable else { return .unreadable }
        return lowest < baseline.onArrival * Self.share ? .stoppedDrawing : .drew
    }

    public var json: JSONValue {
        .object(["onArrival": .number(onArrival), "afterRedraw": .number(afterRedraw)])
    }
}

public struct DrawnWindow: Equatable, Sendable, Codable {
    public static let growth = 1.5

    public var ink: WindowInk

    public var height: Double

    public init(ink: WindowInk = .unreadable, height: Double = 0) {
        self.ink = ink
        self.height = height
    }

    public func letTheHeightEscape(against bounded: DrawnWindow) -> Bool {
        guard bounded.height > 0, height > 0 else { return false }
        return height > bounded.height * Self.growth
            || ink.verdict(against: bounded.ink) == .stoppedDrawing
    }

    public var json: JSONValue {
        .object(["ink": ink.json, "height": .number(height)])
    }
}
