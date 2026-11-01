import Foundation

public enum MergeArchiveDecision: Sendable, Equatable {
    case archiveNow
    case archiveAfterTurn
    case forget
    case leave
}

public enum MergeArchivePolicy {
    public static func seenOpenToRecord(_ pullRequest: PullRequest, recorded: Int?) -> Int? {
        guard pullRequest.isOpen, pullRequest.number > 0, pullRequest.number != recorded else { return nil }
        return pullRequest.number
    }

    public static func decide(
        isEnabled: Bool, seenOpen: Int?, pullRequest: PullRequest, isAgentMidTurn: Bool
    ) -> MergeArchiveDecision {
        guard pullRequest.isMerged, pullRequest.number == seenOpen else { return .leave }
        guard isEnabled else { return .forget }
        return isAgentMidTurn ? .archiveAfterTurn : .archiveNow
    }
}
