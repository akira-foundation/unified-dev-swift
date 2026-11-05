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
        let turn = rows.reversed().prefix { !$0.kind.opensTurn }
        guard let last = turn.first(where: { carriesOutput($0) || isResumeMark($0) }),
              !isResumeMark(last) else { return .other }
        return reportsClaudeUsageLimit(last) ? .usageLimit : .other
    }

    static func noModelWrote(_ line: JSONValue) -> Bool {
        hasSyntheticModel(line) || isAPIError(line)
    }

    private static func hasSyntheticModel(_ line: JSONValue) -> Bool {
        line["message"]?["model"]?.stringValue == measuredSyntheticModel
    }

    private static func isAPIError(_ line: JSONValue) -> Bool {
        line["isApiErrorMessage"]?.boolValue == true
    }

    private static func isResumeMark(_ row: Message) -> Bool {
        row.kind == .handoff && HandoffMark.decode(row.payload) == .resuming
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
              hasSyntheticModel(json),
              json["error"]?.stringValue == measuredError,
              isAPIError(json),
              json["apiErrorStatus"]?.intValue == measuredStatus,
              let text = json["message"]?["content"]?[0]?["text"]?.stringValue
        else { return false }
        return text.range(of: measuredWords, options: [.anchored, .caseInsensitive]) != nil
            && text.localizedCaseInsensitiveContains("limit")
    }
}
