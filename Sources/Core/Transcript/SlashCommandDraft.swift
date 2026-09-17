import Foundation

public struct SlashCommandDraft: Equatable, Sendable {
    public var name: String?
    public var body: String

    public init(name: String?, body: String) {
        self.name = name
        self.body = body
    }

    public var text: String {
        guard let name else { return body }
        return "/\(name) \(body)"
    }

    public static func parse(_ draft: String) -> SlashCommandDraft {
        let whole = SlashCommandDraft(name: nil, body: draft)
        guard draft.hasPrefix("/") else { return whole }

        let afterSlash = draft.dropFirst()
        let name = afterSlash.prefix(while: isNameCharacter)
        guard !name.isEmpty else { return whole }

        let rest = afterSlash.dropFirst(name.count)
        guard rest.first == " " else { return whole }

        return SlashCommandDraft(name: String(name), body: String(rest.dropFirst()))
    }

    public struct Insertion: Equatable, Sendable {
        public var draft: SlashCommandDraft
        public var caret: Int

        public init(draft: SlashCommandDraft, caret: Int) {
            self.draft = draft
            self.caret = caret
        }
    }

    public func picking(command name: String, token: ComposerMenu.Token) -> Insertion {
        let body = self.body as NSString
        let end = min(token.end, body.length)

        if token.start == 0, end == body.length {
            return Insertion(draft: SlashCommandDraft(name: name, body: ""), caret: 0)
        }

        let hasSpace = end < body.length
            && body.substring(with: NSRange(location: end, length: 1)) == " "
        let written = "/" + name + (hasSpace ? "" : " ")
        let replaced = body.replacingCharacters(
            in: NSRange(location: token.start, length: end - token.start),
            with: written
        )
        var draft = self
        draft.body = replaced
        let caret = token.start + (written as NSString).length + (hasSpace ? 1 : 0)
        return Insertion(draft: draft, caret: caret)
    }

    public func removingCommand() -> SlashCommandDraft {
        SlashCommandDraft(name: nil, body: body)
    }

    public func backspacingCommand() -> SlashCommandDraft? {
        guard let name else { return nil }
        guard body.isEmpty else { return removingCommand() }
        return SlashCommandDraft(name: nil, body: "/\(name)")
    }

    public var caretAfterBackspace: Int {
        guard let name, body.isEmpty else { return 0 }
        return ("/\(name)" as NSString).length
    }

    public static func isNameCharacter(_ character: Character) -> Bool {
        character.isASCII
            && (character.isLetter || character.isNumber
                || character == "-" || character == "_" || character == "." || character == ":")
    }
}
