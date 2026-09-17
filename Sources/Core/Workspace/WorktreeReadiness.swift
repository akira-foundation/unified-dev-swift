import Foundation

public enum WorktreeReadiness: Equatable, Sendable, CaseIterable {
    case installing
    case failed
    case ready

    public static func of(isRunningSetup: Bool, setupState: SetupState) -> WorktreeReadiness {
        if isRunningSetup { return .installing }
        switch setupState {
        case .running: return .installing
        case .failed: return .failed
        case .pending, .succeeded, .skipped: return .ready
        }
    }

    public var sentence: String? {
        switch self {
        case .installing: "Setting this worktree up. Its dependencies are still installing."
        case .failed: "Setup failed in this worktree, so its dependencies may be missing."
        case .ready: nil
        }
    }

    public var isSettled: Bool { self != .installing }
}
