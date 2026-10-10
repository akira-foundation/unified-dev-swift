import Foundation

public enum PullRequestStep: String, Sendable, Hashable, CaseIterable {
    case commits
    case pullRequest
    case checks
    case merge

    public var label: String {
        switch self {
        case .commits: "commits"
        case .pullRequest: "pull request"
        case .checks: "checks"
        case .merge: "merge"
        }
    }

    public static let whole = allCases
}

public enum PullRequestReach: Sendable, Hashable {
    case diff
    case pullRequestPage(String)
    case checks
    case merge
}

public struct PullRequestStepLink: Sendable, Hashable {
    public var step: PullRequestStep
    public var reach: PullRequestReach
    public var announcement: String

    public init(step: PullRequestStep, reach: PullRequestReach, announcement: String) {
        self.step = step
        self.reach = reach
        self.announcement = announcement
    }
}
