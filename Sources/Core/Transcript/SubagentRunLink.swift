import Foundation

public enum SubagentRunLink {
    public enum Target: Hashable, Sendable {
        case live(SubagentID)
        case recorded(toolUseID: String)
        case unavailable
    }

    public static let openHelp = "Open this agent's run"
    public static let openActionName = "Open run"
    public static let unavailableLabel = "run not kept"
    public static let unavailableHelp = "Unified Dev kept nothing of this agent's run, so there is nothing to open."

    public static func isAgentCall(toolName: String) -> Bool {
        toolName == "Task" || toolName == "Agent"
    }

    public static func target(
        toolUseID: String?,
        hasRecordedRows: Bool,
        isSettled: Bool,
        liveID: () -> SubagentID?
    ) -> Target {
        guard let toolUseID, !toolUseID.isEmpty else { return .unavailable }
        if let id = liveID() { return .live(id) }
        return hasRecordedRows || !isSettled ? .recorded(toolUseID: toolUseID) : .unavailable
    }

    public static func canOpen(
        toolUseID: String?,
        hasRecordedRows: Bool,
        isSettled: Bool,
        isLive: (String) -> Bool
    ) -> Bool {
        guard let toolUseID, !toolUseID.isEmpty else { return false }
        return hasRecordedRows || !isSettled || isLive(toolUseID)
    }

    public static func recordedSubagent(
        toolUseID: String,
        input: JSONValue?,
        startedAt: Date,
        isSettled: Bool,
        failed: Bool,
        durationMS: Int?
    ) -> Subagent {
        let state: SubagentState = !isSettled ? .running : (failed ? .failed : .completed)
        let seconds = (durationMS ?? 0) / 1_000
        return Subagent(
            id: SubagentID(toolUseID),
            toolUseID: toolUseID,
            description: input?["description"]?.stringValue ?? "",
            type: input?["subagent_type"]?.stringValue ?? "",
            prompt: input?["prompt"]?.stringValue ?? "",
            taskType: "local_agent",
            state: state,
            elapsedSeconds: seconds,
            finishedAt: isSettled ? startedAt.addingTimeInterval(Double(seconds)) : nil,
            startedAt: startedAt
        )
    }
}
