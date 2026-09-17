import Foundation

public enum PullRequestNumber {
    public static func toRecord(found: PullRequest?, recorded: Int?) -> Int? {
        guard let found, found.number > 0, found.number != recorded else { return nil }
        return found.number
    }

    public static func record(_ found: PullRequest?, for workspace: Workspace, in store: Store?) async {
        guard let store, let number = toRecord(found: found, recorded: workspace.pullRequestNumber) else {
            return
        }
        try? await store.recordPullRequestNumber(number, workspaceID: workspace.id)
    }
}
