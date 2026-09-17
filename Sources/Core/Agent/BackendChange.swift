import Foundation

public enum BackendChange: Sendable, Equatable {
    case unchanged
    case changeInPlace(AgentKind)
    case fork(AgentKind)

    public static func decide(from current: AgentKind, to wanted: AgentKind, hasSpoken: Bool) -> BackendChange {
        guard current != wanted else { return .unchanged }
        guard wanted.canRunWorkspaces else { return .unchanged }
        return hasSpoken ? .fork(wanted) : .changeInPlace(wanted)
    }

    public static func hasSpoken(
        rowCount: Int,
        agentSessionID: String?,
        isTranscriptLoaded: Bool
    ) -> Bool {
        if !(agentSessionID ?? "").isEmpty { return true }
        if rowCount > 0 { return true }
        return !isTranscriptLoaded
    }

    public static func forkNotice(title: String, from current: AgentKind) -> String {
        "Opened `\(title)`. Your original \(current.label) conversation is still available."
    }

    public static func forkFailureNotice(to wanted: AgentKind) -> String {
        "Could not open a \(wanted.label) conversation. Your current conversation is unchanged."
    }

    public static func replacementNotice(from current: AgentKind, to wanted: AgentKind) -> String {
        "Started a new \(wanted.label) conversation. Your previous \(current.label) conversation was archived and kept."
    }

    public static func forkedTitle(_ title: String, to kind: AgentKind) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty ? "New session" : trimmed
        let stem = base.components(separatedBy: " on ").first ?? base
        return "\(stem) on \(kind.label)"
    }
}
