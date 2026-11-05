import Foundation

extension ConversationHandoff {
    static func toolLines(_ rows: [Message], unfinished: Bool, capped: Bool) -> [String] {
        var results: [String: AgentToolResult] = [:]
        var uses: [AgentToolUse] = []
        for row in rows {
            switch event(row) {
            case .toolResult(let result)? where row.kind == .toolResult: results[result.toolUseID] = result
            case .toolUse(let use)? where row.kind == .toolUse: uses.append(use)
            default: continue
            }
        }
        let names = Dictionary(uses.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        var subCalls: [String: Int] = [:]
        for use in uses { if let parent = use.parentToolUseID { subCalls[parent, default: 0] += 1 } }

        return uses.compactMap { use -> String? in
            let nested = use.parentToolUseID != nil
            if nested, !unfinished { return nil }
            let result = results[use.id]
            var line = nested ? "  - within \(names[use.parentToolUseID ?? ""] ?? "a sub-agent"): " : "- "
            line += use.name
            if let target = target(of: use) { line += " \(target)" }
            line += ": " + status(of: result, unfinished: unfinished)
            if !unfinished, let count = subCalls[use.id] {
                line += " (made \(count) \(count == 1 ? "sub-call" : "sub-calls"))"
            }
            if unfinished, let result, let summary = oneLine(result.text, limit: capped ? cappedResultLimit : resultSummaryLimit),
               !summary.isEmpty {
                line += "\n  Result: " + summary
            }
            return line
        }
    }

    private static func status(of result: AgentToolResult?, unfinished: Bool) -> String {
        guard let result else { return unfinished ? "no result recorded, it may have run" : "no result" }
        if let refusal = result.refusal { return refusal.label }
        return result.isError ? "failed" : "completed"
    }

    private static func target(of use: AgentToolUse) -> String? {
        guard let value = targetKeys.lazy.compactMap({ use.input[$0]?.stringValue }).first(where: { !$0.isEmpty })
        else { return nil }
        return oneLine(value, limit: targetLimit)
    }

    private static func oneLine(_ text: String, limit: Int) -> String? {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit)) + "..." : flat
    }
}
