import Foundation

public enum Crew {
    public static let ceiling = 10

    public static let nameLimit = 32

    public enum StartRefusal: Error, Equatable {
        case noName
        case nameTaken(String)
        case tooMany(running: Int)
        case notAnOrchestrator
    }

    public static func normalisedName(_ raw: String) -> String? {
        let stripped = raw.unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) ? " " : String($0) }
            .joined()

        let collapsed = stripped
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return nil }

        return String(collapsed.prefix(nameLimit))
    }

    public static func start(
        name raw: String,
        existing: Set<String>,
        running: Int,
        callerIsSubagent: Bool
    ) -> Result<String, StartRefusal> {
        if callerIsSubagent { return .failure(.notAnOrchestrator) }

        guard let name = normalisedName(raw) else { return .failure(.noName) }

        if existing.contains(name) { return .failure(.nameTaken(name)) }

        if running >= ceiling { return .failure(.tooMany(running: running)) }

        return .success(name)
    }

    public static func sentence(for refusal: StartRefusal) -> String {
        switch refusal {
        case .noName:
            "A subagent needs a name. Give it one that says what the agent is for, such as "
                + "\"tests\" or \"read-the-cascade\"."
        case .nameTaken(let name):
            "This workspace already has a subagent called \"\(name)\". Talk to that one with "
                + "agent_say, or start a new one under another name."
        case .tooMany(let running):
            "\(running) subagents are already running in this workspace, which is the limit. "
                + "Stop one with agent_stop, or wait for one to finish."
        case .notAnOrchestrator:
            "A subagent cannot start a subagent. Say what you need to the agent that started you "
                + "and let it decide."
        }
    }

    public static func deliverySentence(to agent: AgentKind) -> String {
        agent.acceptsMidTurnMessage
            ? "It reads this inside the turn it is running, or straight away if it is idle, "
                + "unless something is queued in front of it."
            : "If it is mid turn it will read this when that turn ends."
    }

    public static func stoppedSentence(name: String, lastMessage: String?) -> String {
        guard let last = lastMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !last.isEmpty else {
            return "Your subagent \"\(name)\" has stopped. It said nothing before it did.\n\n"
                + tidyHint
        }

        return "Your subagent \"\(name)\" has stopped. The last thing it said to you:\n\n\(last)"
            + "\n\n" + tidyHint
    }

    public static func failedSentence(name: String, reason: String) -> String {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = trimmed.isEmpty ? "No reason was reported." : trimmed

        return "Your subagent \"\(name)\" stopped without finishing. \(tail)"
    }

    public static func stoppedByOwnerSentence(name: String) -> String {
        "Your subagent \"\(name)\" was stopped by the owner, who was watching it. It is gone: "
            + "its row and its name have been let go. Do not start another one in its place "
            + "unless they ask for it. Carry on with your own work."
    }

    public static func stoppedByOwnerSummary(name: String) -> String {
        "\(name) stopped by you"
    }

    public static func stoppedSummary(name: String) -> String {
        "\(name) stopped"
    }

    public static func failedSummary(name: String, reason: String) -> String {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(name) stopped without finishing" : "\(name) failed. \(trimmed)"
    }

    public static let tidyHint =
        "If you have no more work for it, call agent_stop on it now: that ends it and takes its "
        + "row out of the sidebar. If you will send it more work, leave it alone, because it "
        + "keeps everything it has read."

    public static func message(from name: String, saying text: String) -> String {
        BridgeUntrustedText.wrapSaying(text, from: "your subagent \"\(name)\"")
    }
}
