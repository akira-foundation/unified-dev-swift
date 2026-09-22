import Foundation

public enum WorkspaceTurnEnding: Sendable, Hashable {
    case finished(lastMessage: String?)
    case stoppedByOwner
    case failed(reason: String)
    case waitingOnPermission(tool: String)
    case waitingOnQuestion
    case archived

    public static func ofResult(_ result: AgentResult, stoppedByOwner: Bool) -> WorkspaceTurnEnding {
        if stoppedByOwner { return .stoppedByOwner }
        if result.succeeded { return .finished(lastMessage: result.summary) }
        let reason = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failed(reason: reason.isEmpty ? result.subtype : reason)
    }

    public static func ofAsk(_ ask: PermissionAsk) -> WorkspaceTurnEnding {
        ask.isQuestion ? .waitingOnQuestion : .waitingOnPermission(tool: ask.toolName)
    }
}
