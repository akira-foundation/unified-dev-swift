import Foundation

public enum TurnEnding: Sendable, Hashable {
    case finished
    case denied(Int)
    case failed
    case stopped

    public static func of(wasStopped: Bool, succeeded: Bool, denials: Int) -> TurnEnding {
        if wasStopped { return .stopped }
        if !succeeded { return .failed }
        if denials > 0 { return .denied(denials) }
        return .finished
    }

    public var label: String {
        switch self {
        case .finished: "Finished"
        case .denied: "Finished, with calls denied"
        case .failed: "Failed"
        case .stopped: "Stopped"
        }
    }

    public func note(permissionMode: PermissionMode, agentKind: AgentKind) -> String? {
        switch self {
        case .finished, .failed:
            nil
        case .denied(let count):
            "\(count == 1 ? "1 tool call was" : "\(count) tool calls were") denied in "
                + "\(permissionMode.label(on: agentKind)). Pick another permission mode under "
                + "the composer, then ask again."
        case .stopped:
            "You stopped this turn. Everything the agent had already changed is still in the "
                + "worktree, and you can ask for something else whenever you like."
        }
    }
}
