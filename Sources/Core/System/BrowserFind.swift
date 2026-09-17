import Foundation

public struct BrowserFind: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case idle
        case found
        case notFound
    }

    public var isShowing = false
    public var query = ""
    public var outcome: Outcome = .idle

    public init() {}

    public var canStep: Bool { !query.isEmpty }

    public var status: String {
        switch outcome {
        case .idle, .found: ""
        case .notFound: "Not found"
        }
    }

    public var isCaseSensitive: Bool {
        query.contains { $0.isUppercase }
    }

    public private(set) var opens = 0

    public mutating func show() {
        isShowing = true
        opens += 1
    }

    public mutating func hide() {
        isShowing = false
        outcome = .idle
    }

    public mutating func type(_ text: String) {
        query = text
        if text.isEmpty { outcome = .idle }
    }

    public mutating func settle(matched: Bool) {
        guard canStep else { return outcome = .idle }
        outcome = matched ? .found : .notFound
    }
}

public enum BrowserFindCommand: Sendable, Equatable {
    case show
    case next
    case previous
    case hide

    public static func forKey(
        _ characters: String,
        hasCommand: Bool,
        hasShift: Bool
    ) -> BrowserFindCommand? {
        guard hasCommand else { return nil }
        switch characters.lowercased() {
        case "f": return hasShift ? nil : .show
        case "g": return hasShift ? .previous : .next
        default: return nil
        }
    }
}
