import Foundation

public enum StrayResult {
    public static func isStray(_ result: AgentResult) -> Bool {
        !result.origin.isEmpty && didNothing(result)
    }

    private static func didNothing(_ result: AgentResult) -> Bool {
        !result.isError
            && result.numTurns == 0
            && result.durationAPIMS == 0
            && result.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
