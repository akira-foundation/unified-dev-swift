import Foundation

public enum ConversationTurnPresence: Sendable, Equatable {
    case retained(threadID: String)
    case absent(threadID: String)
    case threadMissing
}

public extension CheckpointRewind {
    enum RecoveryDecision: Sendable, Equatable {
        case completeRewind
        case undoRewind
        case undoUnproven
    }

    static let unprovenRecoveryNotice =
        "Unified Dev could not confirm the agent went back, so the rewind was undone and the conversation kept."

    func recoveryDecision(given presence: ConversationTurnPresence) -> RecoveryDecision {
        switch presence {
        case .retained:
            .undoRewind
        case .absent(let threadID) where threadID == providerThreadID:
            .completeRewind
        case .absent, .threadMissing:
            .undoUnproven
        }
    }
}
