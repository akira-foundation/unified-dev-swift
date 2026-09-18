import Foundation

public struct PullRequestRefreshState: Sendable, Equatable {
    public private(set) var pullRequest: PullRequest?
    public private(set) var failure: GitHubReadFailure?
    private var dismissed: DismissedFailure?

    private struct DismissedFailure: Sendable, Equatable {
        let reason: GitHubReadFailure.Reason
        let message: String?

        init(_ failure: GitHubReadFailure) {
            reason = failure.reason
            message = failure.reason == .rateLimited ? nil : failure.message
        }
    }

    public init(pullRequest: PullRequest? = nil) {
        self.pullRequest = pullRequest
    }

    public var visibleFailure: GitHubReadFailure? {
        guard let failure else { return nil }
        return dismissed == DismissedFailure(failure) ? nil : failure
    }

    public mutating func record(_ read: PullRequestRead) {
        switch read {
        case .current(let pullRequest):
            self.pullRequest = pullRequest
            failure = nil
            dismissed = nil
        case .unavailable(let failure):
            self.failure = failure
            if dismissed != DismissedFailure(failure) { dismissed = nil }
        }
    }

    public mutating func dismissFailure() {
        dismissed = failure.map(DismissedFailure.init)
    }
}
