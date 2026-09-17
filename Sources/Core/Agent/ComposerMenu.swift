import Foundation

public enum ComposerMenu: Equatable, Sendable {
    case none
    case slash(Token)
    case mention(Token)

    public struct Token: Equatable, Sendable {
        public var start: Int
        public var length: Int
        public var query: String

        public init(start: Int, length: Int, query: String) {
            self.start = start
            self.length = length
            self.query = query
        }

        public var end: Int { start + length }
    }

    public enum Kind: Sendable {
        case none
        case slash
        case mention
    }

    public var kind: Kind {
        switch self {
        case .none: .none
        case .slash: .slash
        case .mention: .mention
        }
    }

    public var query: String? {
        switch self {
        case .none: nil
        case .slash(let token), .mention(let token): token.query
        }
    }

    public var slash: Token? {
        guard case .slash(let token) = self else { return nil }
        return token
    }

    public var mention: Token? {
        guard case .mention(let token) = self else { return nil }
        return token
    }

    public static func resolve(draft: String, caret: Int) -> ComposerMenu {
        if let token = slashToken(in: draft, caret: caret) { return .slash(token) }
        if let token = mentionToken(in: draft, caret: caret) { return .mention(token) }
        return .none
    }

    public static func slashToken(in draft: String, caret: Int) -> Token? {
        token(in: draft, caret: caret, opener: "/")
    }

    public static func mentionToken(in draft: String, caret: Int) -> Token? {
        token(in: draft, caret: caret, opener: "@")
    }

    private static func token(in draft: String, caret: Int, opener: String) -> Token? {
        let text = draft as NSString
        let location = min(max(caret, 0), text.length)
        guard location > 0 else { return nil }

        let before = text.substring(to: location) as NSString
        let found = before.range(of: opener, options: .backwards)
        guard found.location != NSNotFound else { return nil }

        let query = before.substring(from: found.location + 1)
        guard !query.contains(where: isBreak) else { return nil }
        guard beginsAWord(in: before, at: found.location) else { return nil }

        return Token(start: found.location, length: location - found.location, query: query)
    }

    private static func beginsAWord(in text: NSString, at location: Int) -> Bool {
        guard location > 0 else { return true }
        let previous = text.substring(with: NSRange(location: location - 1, length: 1))
        return [" ", "\n", "\t", "(", "["].contains(previous)
    }

    private static func isBreak(_ character: Character) -> Bool {
        character == " " || character == "\n" || character == "\t"
    }
}
