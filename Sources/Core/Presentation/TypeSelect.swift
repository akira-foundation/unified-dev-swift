import Foundation

public struct TypeSelect: Sendable, Equatable {
    public static let window: TimeInterval = 0.75

    public private(set) var buffer = ""

    private var typedAt: Date?

    public init() {}

    public mutating func accept(_ character: Character, at now: Date) -> String {
        if let typedAt, now.timeIntervalSince(typedAt) > Self.window {
            buffer = ""
        }
        if let typedAt, now < typedAt {
            buffer = ""
        }
        buffer.append(character)
        typedAt = now
        return buffer
    }

    public mutating func clear() {
        buffer = ""
        typedAt = nil
    }

    public static func isTypeSelect(_ character: Character) -> Bool {
        guard !character.isWhitespace, !character.isNewline else { return false }
        return character.isLetter || character.isNumber
            || character.isPunctuation || character.isSymbol
    }

    public static func match(_ prefix: String, in titles: [String], from current: Int?) -> Int? {
        guard !prefix.isEmpty, !titles.isEmpty else { return nil }

        let start = prefix.count == 1
            ? (current.map { $0 + 1 } ?? 0)
            : (current ?? 0)

        let found = (0 ..< titles.count).first { offset in
            titles[(start + offset) % titles.count].range(
                of: prefix,
                options: [.anchored, .caseInsensitive, .diacriticInsensitive]
            ) != nil
        }

        return found.map { (start + $0) % titles.count }
    }
}
