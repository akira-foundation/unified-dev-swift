import Foundation

public enum PullRequestProgress {
    public static func announces(hasAnswered: Bool, hasPullRequest: Bool) -> Bool {
        !hasAnswered && !hasPullRequest
    }
}
