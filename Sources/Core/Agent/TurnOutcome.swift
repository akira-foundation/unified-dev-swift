import Foundation

public enum TurnOutcome: Sendable, Hashable {
    case finished
    case needsInput
    case failed

    public var event: NotificationEvent {
        switch self {
        case .finished: .turnFinished
        case .needsInput: .needsInput
        case .failed: .agentFailed
        }
    }
}

public extension AgentResult {
    func outcome(wasCancelled: Bool) -> TurnOutcome? {
        if wasCancelled { return nil }

        if subtype == "error_max_turns" { return .needsInput }
        if permissionDenials > 0 { return .needsInput }
        if isError { return .failed }
        return .finished
    }
}
