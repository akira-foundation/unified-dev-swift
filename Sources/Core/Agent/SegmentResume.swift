import Foundation

public enum SegmentResume {
    public static func lostHistory(requested: String?, received: String?) -> Bool {
        guard let requested, !requested.isEmpty, let received, !received.isEmpty else { return false }
        return requested != received
    }

    public static func refused(requested: String?, result: AgentResult) -> Bool {
        guard let requested, !requested.isEmpty else { return false }
        return result.isError && result.subtype == "error_during_execution" && result.sessionID == requested
    }
}
