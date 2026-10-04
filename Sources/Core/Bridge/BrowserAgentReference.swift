import Foundation

public struct BrowserAgentReference: Sendable, Hashable, CustomStringConvertible {
    public let index: Int

    public init(index: Int) {
        self.index = index
    }

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let bare = trimmed.count > 1 && trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
            ? String(trimmed.dropFirst().dropLast())
            : trimmed
        let folded = bare.lowercased()
        guard folded.hasPrefix("e") else { return nil }
        let digits = folded.dropFirst()
        guard !digits.isEmpty,
              digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              let index = Int(digits),
              index > 0
        else { return nil }
        self.index = index
    }

    public var token: String { "e\(index)" }

    public var description: String { token }
}

public struct BrowserAgentHandles: Sendable, Equatable {
    public private(set) var generation = 0

    public private(set) var count = 0

    public init() {}

    public mutating func recorded(count: Int) {
        generation += 1
        self.count = max(0, count)
    }

    public mutating func pageChanged() {
        generation += 1
        count = 0
    }

    public func refusal(for reference: BrowserAgentReference, tool: String) -> String? {
        guard count > 0 else {
            return "\(tool) acts on an element of the page as it is now, and Unified Dev is "
                + "holding none. Call browser_snapshot first: it writes the page out and gives "
                + "every element a reference like [e1]. A reference lasts until the next "
                + "snapshot, and the moment the page navigates they all stop meaning anything."
        }
        guard (1...count).contains(reference.index) else {
            return "There is no \(reference.token) on this page. The last browser_snapshot found "
                + "\(count) elements, so the references run from e1 to e\(count). Call "
                + "browser_snapshot again if the page has changed since, rather than guessing at "
                + "a number."
        }
        return nil
    }
}
