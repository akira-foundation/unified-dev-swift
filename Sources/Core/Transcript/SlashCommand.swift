import Foundation

public struct SlashCommand: Identifiable, Hashable, Sendable {
    public enum Scope: Hashable, Sendable {
        case builtIn
        case user
        case project
        case plugin(String)
    }

    public enum Kind: Hashable, Sendable {
        case command
        case skill
    }

    public var name: String
    public var detail: String
    public var kind: Kind
    public var scope: Scope
    public var path: String?

    public var id: String { name }

    public init(name: String, detail: String, kind: Kind, scope: Scope, path: String? = nil) {
        self.name = name
        self.detail = detail
        self.kind = kind
        self.scope = scope
        self.path = path
    }

    public var badge: String? {
        scope == .project ? "project" : nil
    }
}

public struct SlashCommandMatch: Identifiable, Hashable, Sendable {
    public var command: SlashCommand
    public var score: Int
    public var highlights: [Int]

    public var id: String { command.id }

    public init(command: SlashCommand, score: Int, highlights: [Int]) {
        self.command = command
        self.score = score
        self.highlights = highlights
    }
}

extension SlashCommand {
    public static func rank(_ commands: [SlashCommand], query: String) -> [SlashCommandMatch] {
        guard !query.isEmpty else {
            return commands.map { SlashCommandMatch(command: $0, score: 0, highlights: []) }
        }

        var found: [SlashCommandMatch] = []
        found.reserveCapacity(commands.count)

        for command in commands {
            guard let hit = FuzzyMatch.hit(command.name, query: query) else { continue }
            found.append(SlashCommandMatch(
                command: command,
                score: hit.score + (command.kind == .command ? 1 : 0),
                highlights: hit.positions
            ))
        }

        found.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.command.name < rhs.command.name
        }
        return found
    }
}
