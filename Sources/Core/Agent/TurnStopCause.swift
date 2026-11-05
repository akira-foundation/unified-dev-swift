import Foundation

public enum TurnStopCause: Sendable, Equatable {
    case usageLimit
    case other

    static let measuredSyntheticModel = "<synthetic>"
    static let measuredError = "rate_limit"
    static let measuredStatus = 429
    static let measuredWords = "You've hit your"

    public static func ofLastTurn(messages: [Message], agent: AgentKind) -> TurnStopCause {
        guard agent == .claudeCode else { return .other }
        let rows = messages.sorted { $0.seq < $1.seq }
        let turn = rows.reversed().prefix { $0.kind != .user }
        guard let last = turn.first(where: carriesOutput) else { return .other }
        return reportsClaudeUsageLimit(last) ? .usageLimit : .other
    }

    private static func carriesOutput(_ row: Message) -> Bool {
        switch row.kind {
        case .assistantText, .thinking, .toolUse, .toolResult, .permissionAsk: true
        default: false
        }
    }

    private static func reportsClaudeUsageLimit(_ row: Message) -> Bool {
        guard row.kind == .assistantText,
              let json = JSONValue.parse(row.payload),
              json["type"]?.stringValue == "assistant",
              json["message"]?["model"]?.stringValue == measuredSyntheticModel,
              json["error"]?.stringValue == measuredError,
              json["isApiErrorMessage"]?.boolValue == true,
              json["apiErrorStatus"]?.intValue == measuredStatus,
              let text = json["message"]?["content"]?[0]?["text"]?.stringValue
        else { return false }
        return text.range(of: measuredWords, options: [.anchored, .caseInsensitive]) != nil
            && text.localizedCaseInsensitiveContains("limit")
    }
}
