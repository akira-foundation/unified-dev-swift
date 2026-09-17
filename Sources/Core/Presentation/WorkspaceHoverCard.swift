import Foundation

public struct WorkspaceHoverCard: Sendable, Hashable {
    public struct Diff: Sendable, Hashable {
        public var additions: Int
        public var deletions: Int

        public init(additions: Int, deletions: Int) {
            self.additions = additions
            self.deletions = deletions
        }
    }

    public struct PullRequestRef: Sendable, Hashable {
        public var number: Int
        public var title: String
        public var url: String

        public init(number: Int, title: String, url: String) {
            self.number = number
            self.title = title
            self.url = url
        }
    }

    public var title: String
    public var branch: String
    public var diff: Diff?
    public var status: WorkspaceStatus
    public var state: String
    public var detail: String?
    public var pullRequest: PullRequestRef?
    public var age: String

    public init(
        title: String,
        branch: String,
        diff: Diff? = nil,
        status: WorkspaceStatus,
        state: String,
        detail: String? = nil,
        pullRequest: PullRequestRef? = nil,
        age: String
    ) {
        self.title = title
        self.branch = branch
        self.diff = diff
        self.status = status
        self.state = state
        self.detail = detail
        self.pullRequest = pullRequest
        self.age = age
    }

    public static func make(
        workspace: Workspace,
        isRunning: Bool = false,
        isAwaitingPermission: Bool = false,
        pullRequest: PullRequest? = nil,
        now: Date = Date()
    ) -> WorkspaceHoverCard {
        let status = WorkspaceStatus.resolve(
            workspace: workspace,
            isRunning: isRunning,
            pullRequest: pullRequest,
            isAwaitingPermission: isAwaitingPermission
        )

        return WorkspaceHoverCard(
            title: workspace.name,
            branch: workspace.branch,
            diff: counts(for: workspace),
            status: status,
            state: status.label,
            detail: status.detail(pullRequest: pullRequest),
            pullRequest: reference(to: pullRequest),
            age: HomeAge.phrase(for: workspace.lastActivityAt, now: now)
        )
    }

    static func counts(for workspace: Workspace) -> Diff? {
        workspace.hasDiff
            ? Diff(additions: workspace.additions, deletions: workspace.deletions)
            : nil
    }

    static func reference(to pullRequest: PullRequest?) -> PullRequestRef? {
        pullRequest.map {
            PullRequestRef(number: $0.number, title: $0.title, url: $0.url)
        }
    }
}
