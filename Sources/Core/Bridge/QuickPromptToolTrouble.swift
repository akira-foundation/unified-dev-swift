import Foundation

public enum QuickPromptTrouble: Error, Sendable, Equatable {
    case noText
    case blankText(field: String)
    case noID(tool: String)
    case unknownID(id: String, known: [QuickPrompt])
    case emptyLibrary(tool: String)
    case nothingToChange
    case unknownSymbol(String)
    case unexplained(tool: String, message: String)

    public var sentence: String {
        switch self {
        case .noText:
            return """
                quick_prompt_create needs the 'text' the prompt puts in the composer, and it \
                cannot be blank: a prompt with no words in it inserts nothing. 'name' and \
                'symbol' are optional, 'text' is the prompt.
                """

        case .blankText(let field):
            return """
                '\(field)' arrived empty, and a quick prompt with no words in it inserts nothing. \
                Pass the text the prompt should put in the composer, or leave '\(field)' out \
                entirely to keep the text this prompt already has.
                """

        case .noID(let tool):
            return """
                \(tool) needs the 'id' of the quick prompt to act on, which is the id \
                quick_prompt_list prints. It takes an id and not a name, because two prompts can \
                share a name and picking one of them would be the wrong prompt. Call \
                quick_prompt_list first.
                """

        case let .unknownID(id, known):
            return """
                Unified Dev has no quick prompt with the id '\(id)'. It has \(Self.listing(known)). \
                Retrying with the same id will fail the same way: call quick_prompt_list and use \
                an id from its answer.
                """

        case .emptyLibrary(let tool):
            return """
                Unified Dev has no quick prompts, so \(tool) has nothing to act on. Retrying will not \
                change that. quick_prompt_create is what writes one.
                """

        case .nothingToChange:
            return """
                quick_prompt_update was given a prompt and nothing to do to it. Pass at least one \
                of 'name', 'symbol' or 'text'. Whatever you leave out keeps the value it already \
                has, so changing the name alone is a call with 'id' and 'name' and nothing else.
                """

        case .unknownSymbol(let symbol):
            return """
                Unified Dev cannot draw '\(symbol)' as a quick prompt's mark, and a mark it cannot draw \
                is a blank down the left of the row. Pass one emoji, or one of the SF Symbol \
                names Unified Dev's own picker offers, such as \(Self.symbolExamples). Leave 'symbol' \
                out for Unified Dev's default.
                """

        case let .unexplained(tool, message):
            return "Unified Dev could not finish \(tool): \(message)"
        }
    }

    static var symbolExamples: String {
        let names = ["doc.richtext", "hammer", "text.alignleft"].filter(QuickPrompt.knownSymbols.contains)
        let usable = names.isEmpty ? Array(QuickPrompt.symbols.prefix(3)) : names
        return usable.map { "'\($0)'" }.joined(separator: ", ")
    }

    static let listingLimit = 12

    static func listing(_ prompts: [QuickPrompt]) -> String {
        guard !prompts.isEmpty else { return "none at all" }
        let named = prompts.prefix(listingLimit)
            .map { "'\($0.resolvedName)' (id \($0.id.rawValue))" }
            .joined(separator: ", ")
        guard prompts.count > listingLimit else { return named }
        return "\(named), and \(prompts.count - listingLimit) more"
    }
}
