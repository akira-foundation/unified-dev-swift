import Foundation

public struct QuickPromptMatches: Sendable, Hashable {
    public let query: String
    public let prompts: [QuickPrompt]

    public init(query: String = "", prompts: [QuickPrompt] = []) {
        self.query = query
        self.prompts = prompts
    }

    public var isEmpty: Bool { prompts.isEmpty }

    public static func ranking(
        _ prompts: [QuickPrompt], query: String, limit: Int = 100
    ) -> QuickPromptMatches {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = ranked(prompts, query: trimmed, limit: limit, name: \.resolvedName, text: \.text)
        return QuickPromptMatches(query: trimmed, prompts: rows)
    }

    static func ranked<Row>(
        _ rows: [Row], query trimmed: String, limit: Int,
        name: (Row) -> String, text: (Row) -> String
    ) -> [Row] {
        guard !trimmed.isEmpty else { return Array(rows.prefix(limit)) }

        var scored: [(row: Row, score: Int, position: Int)] = []
        scored.reserveCapacity(rows.count)
        for (position, row) in rows.enumerated() {
            let nameScore = FuzzyMatch.score(name(row), query: trimmed)
            let body = text(row).range(of: trimmed, options: .caseInsensitive) != nil
                ? bodyScore
                : nil
            guard nameScore != nil || body != nil else { continue }
            scored.append((row, (nameScore ?? 0) + (body ?? 0), position))
        }
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.position < rhs.position
        }
        return scored.prefix(limit).map(\.row)
    }

    private static let bodyScore = 1

    public func stepped(from current: QuickPrompt?, by step: Int) -> QuickPrompt? {
        MenuRows.stepped(from: current, by: step, in: prompts)
    }

    public func settled(after current: QuickPrompt?) -> QuickPrompt? {
        guard let current, let held = prompts.first(where: { $0.id == current.id }) else {
            return prompts.first
        }
        return held
    }
}
