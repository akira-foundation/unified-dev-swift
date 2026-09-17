import Foundation

public enum SubagentState: String, Sendable, Hashable, CaseIterable, Codable {
    case running
    case completed
    case failed
    case stopped

    public var isFinished: Bool { self != .running }
}

public enum SubagentLifecycleEvent: Sendable, Hashable {
    case spawned
    case resumed
    case reported(status: String)
    case agentExited
}

extension SubagentState {
    public init?(reported status: String) {
        switch status.lowercased() {
        case "running", "in_progress", "in-progress", "started", "pending", "queued":
            self = .running
        case "completed", "complete", "success", "succeeded", "done", "finished":
            self = .completed
        case "failed", "failure", "error", "errored":
            self = .failed
        case "killed", "cancelled", "canceled", "stopped", "aborted", "interrupted", "refused":
            self = .stopped
        default:
            return nil
        }
    }

    public func transition(on event: SubagentLifecycleEvent) -> StateTransition<SubagentState> {
        switch event {
        case .spawned:
            guard self == .running else { return .refused }
            return .unchanged
        case .resumed:
            return self == .running ? .unchanged : .moves(to: .running)

        case .reported(let status):
            guard let reported = SubagentState(reported: status) else { return .refused }
            guard self == .running else {
                return self == reported ? .unchanged : .refused
            }
            return reported == .running ? .unchanged : .moves(to: reported)

        case .agentExited:
            guard self == .running else { return .unchanged }
            return .moves(to: .stopped)
        }
    }
}
