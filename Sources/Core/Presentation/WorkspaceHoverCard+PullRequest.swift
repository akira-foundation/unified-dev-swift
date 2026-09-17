import Foundation

public extension WorkspaceHoverCard {
    static func pullRequestBand(
        workspace: Workspace,
        pullRequest: PullRequest?,
        localWork: LocalWork? = nil,
        now: Date = Date()
    ) -> WorkspaceHoverCard {
        let resolved = verdict(
            workspace: workspace, pullRequest: pullRequest, localWork: localWork
        )

        return WorkspaceHoverCard(
            title: headline(workspace: workspace, pullRequest: pullRequest),
            branch: workspace.branch,
            diff: counts(for: workspace),
            status: resolved.status,
            state: resolved.state,
            detail: resolved.detail,
            pullRequest: reference(to: pullRequest),
            age: HomeAge.phrase(for: workspace.lastActivityAt, now: now)
        )
    }

    private static func headline(workspace: Workspace, pullRequest: PullRequest?) -> String {
        let given = pullRequest?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return given.isEmpty ? workspace.name : given
    }

    private static func verdict(
        workspace: Workspace,
        pullRequest: PullRequest?,
        localWork: LocalWork?
    ) -> (status: WorkspaceStatus, state: String, detail: String?) {
        let mark = WorkspaceStatus.ofBranch(workspace: workspace, pullRequest: pullRequest)

        guard let pullRequest else {
            return (
                mark,
                "No pull request yet",
                workspace.hasDiff
                    ? "Target \(workspace.baseBranch)"
                    : "Nothing has changed on this branch yet"
            )
        }

        let live = pullRequest.status(local: localWork)
        let tookOver = live.text != pullRequest.status.text
        var detail = live.detail
        if let text = detail, text.isEmpty || text == live.text { detail = nil }

        return (tookOver ? .changed : mark, live.text, detail)
    }
}
