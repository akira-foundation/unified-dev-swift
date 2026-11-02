import Foundation

public enum MergeArchiveDecision: Sendable, Equatable {
    case archiveNow
    case archiveAfterTurn
    case waitForCommand
    case forget
    case leave
}

public enum MergeArchivePolicy {
    public static func seenOpenToRecord(_ pullRequest: PullRequest, recorded: Int?) -> Int? {
        guard pullRequest.isOpen, pullRequest.number > 0, pullRequest.number != recorded else { return nil }
        return pullRequest.number
    }

    public static func decide(
        isEnabled: Bool,
        seenOpen: Int?,
        pullRequest: PullRequest,
        isAgentMidTurn: Bool,
        isCommandRunning: Bool = false
    ) -> MergeArchiveDecision {
        guard pullRequest.isMerged, pullRequest.number == seenOpen else { return .leave }
        guard isEnabled else { return .forget }
        guard !isAgentMidTurn else { return .archiveAfterTurn }
        return isCommandRunning ? .waitForCommand : .archiveNow
    }
}
