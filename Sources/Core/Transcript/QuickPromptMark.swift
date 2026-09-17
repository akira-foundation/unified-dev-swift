import Foundation

public enum QuickPromptMark: Sendable, Hashable {
    case symbol(String)
    case emoji(String)

    public init(stored: String) {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 1, let character = trimmed.first, Self.isEmoji(character) {
            self = .emoji(String(character))
        } else if QuickPrompt.knownSymbols.contains(trimmed) {
            self = .symbol(trimmed)
        } else {
            self = .fallback
        }
    }

    public static let fallback = QuickPromptMark.symbol(QuickPrompt.defaultSymbol)

    public var stored: String {
        switch self {
        case .symbol(let name): name
        case .emoji(let emoji): emoji
        }
    }

    public var isEmoji: Bool {
        if case .emoji = self { return true }
        return false
    }

    private static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first, first.properties.isEmoji else { return false }
        return first.properties.isEmojiPresentation || scalars.count > 1
    }
}
