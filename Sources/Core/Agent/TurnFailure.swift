import Foundation

public struct TurnFailure: Sendable, Hashable {
    public let lead: String?
    public let clisOwnWords: String?

    public static func of(_ result: AgentResult) -> TurnFailure? {
        guard !result.succeeded else { return nil }
        let words = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let lead = self.lead(terminalReason: result.terminalReason, stopReason: result.stopReason)
        guard lead != nil || !words.isEmpty else { return nil }
        return TurnFailure(lead: lead, clisOwnWords: words.isEmpty ? nil : words)
    }

    static func lead(terminalReason: String?, stopReason: String?) -> String? {
        switch terminalReason {
        case "api_error":
            return "The turn stopped at the API's end rather than yours, so whatever the agent "
                + "had already changed is still in the worktree."
        case "max_tokens":
            return "The turn ran out of room to answer in. Nothing is lost, and a narrower "
                + "question will fit."
        default:
            return nil
        }
    }
}
