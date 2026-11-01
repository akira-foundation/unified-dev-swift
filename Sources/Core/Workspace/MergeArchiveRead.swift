import Foundation

public enum MergeArchiveRead {
    public static func note(
        _ pullRequest: PullRequest,
        workspaceID: WorkspaceID,
        isEnabled: Bool,
        isAgentMidTurn: Bool,
        store: Store
    ) async throws -> MergeArchiveDecision {
        let seenOpen = try await store.pullRequestSeenOpen(workspaceID: workspaceID)
        if let number = MergeArchivePolicy.seenOpenToRecord(pullRequest, recorded: seenOpen) {
            try await store.recordPullRequestSeenOpen(number, workspaceID: workspaceID)
            return .leave
        }
        let decision = MergeArchivePolicy.decide(
            isEnabled: isEnabled, seenOpen: seenOpen, pullRequest: pullRequest, isAgentMidTurn: isAgentMidTurn
        )
        switch decision {
        case .leave, .archiveAfterTurn:
            return decision
        case .forget:
            try await store.recordPullRequestSeenOpen(nil, workspaceID: workspaceID)
            return .forget
        case .archiveNow:
            let taken = try await store.takePullRequestSeenOpen(pullRequest.number, workspaceID: workspaceID)
            return taken ? .archiveNow : .leave
        }
    }
}
