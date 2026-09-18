import Foundation

public enum SubagentPane: Sendable {
    public static let refreshSeconds: Double = 1.0

    public static func refreshes(_ subagent: Subagent?) -> Bool {
        subagent?.state == .running
    }

    public static func nothingToShow(
        _ failure: SubagentOutput.Failure, kind: SubagentKind, isRunning: Bool
    ) -> String {
        guard isRunning else { return failure.sentence(kind) }
        switch kind {
        case .agent: return "It has not said anything yet."
        case .command: return "It has not printed anything yet."
        }
    }

    public static func subtitle(_ subagent: Subagent, now: Date = Date()) -> String {
        var parts: [String] = []
        switch subagent.kind {
        case .command:
            parts.append(subagent.kind.noun)
        case .agent:
            let type = subagent.type.trimmingCharacters(in: .whitespacesAndNewlines)
            parts.append(type.isEmpty ? subagent.kind.noun : type)
            if subagent.spawnDepth > 1 {
                parts.append("spawned by a subagent, depth \(subagent.spawnDepth)")
            }
        }
        let elapsed = SubagentRow.duration(subagent.secondsElapsed(at: now))
        if !elapsed.isEmpty { parts.append(elapsed) }
        return parts.joined(separator: " · ")
    }

    public static func briefLabel(_ kind: SubagentKind) -> String {
        switch kind {
        case .agent: "Asked"
        case .command: "Ran"
        }
    }

    public static func outputLabel(_ kind: SubagentKind) -> String {
        switch kind {
        case .agent: "Did"
        case .command: "Printed"
        }
    }

    public static func briefIsCode(_ kind: SubagentKind) -> Bool {
        kind == .command
    }

    public static let briefCollapseLimit = 500

    public static func briefCollapses(_ brief: String) -> Bool {
        brief.count > briefCollapseLimit
    }

    public static func briefToggle(isExpanded: Bool, kind: SubagentKind) -> String {
        switch (isExpanded, kind) {
        case (false, .agent): "Show the prompt"
        case (true, .agent): "Hide the prompt"
        case (false, .command): "Show the command"
        case (true, .command): "Hide the command"
        }
    }

    public static func commandLine(inPayload payload: Data) -> String? {
        guard let line = String(data: payload, encoding: .utf8),
              case .toolUse(let use)? = AgentEvent.decode(line: line)
        else { return nil }
        let command = (use.input["command"]?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : command
    }
}
