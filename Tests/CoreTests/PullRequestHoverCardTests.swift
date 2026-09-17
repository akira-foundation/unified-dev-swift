import Foundation
import Testing
@testable import Core

@Suite("Pull request hover card")
struct PullRequestHoverCardTests {
    static let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func workspace(
        name: String = "Answer a review support question",
        branch: String = "freekmurze/review-support-question",
        baseBranch: String = "main",
        additions: Int = 0,
        deletions: Int = 0,
        changedFiles: Int = 0,
        unread: Bool = false,
        lastActivityAt: Date = PullRequestHoverCardTests.now
    ) -> Workspace {
        Workspace(
            repoID: RepoID("repo"),
            name: name,
            branch: branch,
            path: "/tmp/worktree",
            baseBranch: baseBranch,
            createdAt: lastActivityAt,
            lastActivityAt: lastActivityAt,
            additions: additions,
            deletions: deletions,
            changedFiles: changedFiles,
            unread: unread
        )
    }

    private func pullRequest(
        number: Int = 362,
        title: String = "Answer a review support question",
        state: String = "OPEN",
        mergeable: String? = nil,
        checks: PullRequest.Checks = .none,
        checksSummary: String = "",
        reviewDecision: String? = nil
    ) -> PullRequest {
        PullRequest(
            number: number,
            title: title,
            url: "https://github.com/akira-io/unifieddev/pull/\(number)",
            state: state,
            mergeable: mergeable,
            checks: checks,
            checksSummary: checksSummary,
            reviewDecision: reviewDecision
        )
    }

    @Test("The branch is carried whole, prefix and all")
    func branchIsWhole() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 118, deletions: 6, changedFiles: 4),
            pullRequest: nil,
            now: Self.now
        )

        #expect(card.branch == "freekmurze/review-support-question")
    }

    @Test("A branch with slashes keeps every one of them")
    func branchWithSlashes() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(branch: "agent/2026-08/fix-the-checks"),
            pullRequest: nil,
            now: Self.now
        )

        #expect(card.branch == "agent/2026-08/fix-the-checks")
    }

    @Test("A branch with work and no pull request says so, and where it is headed")
    func noPullRequestWithChanges() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 118, deletions: 6, changedFiles: 4),
            pullRequest: nil,
            now: Self.now
        )

        #expect(card.title == "Answer a review support question")
        #expect(card.state == "No pull request yet")
        #expect(card.detail == "Target main")
        #expect(card.status == .changed)
        #expect(card.pullRequest == nil)
        #expect(card.diff == WorkspaceHoverCard.Diff(additions: 118, deletions: 6))
    }

    @Test("The target is the workspace's own base branch")
    func targetFollowsTheBase() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(baseBranch: "develop", additions: 3, changedFiles: 1),
            pullRequest: nil,
            now: Self.now
        )

        #expect(card.detail == "Target develop")
    }

    @Test("A branch with nothing on it says that rather than naming a target")
    func noPullRequestAndNoChanges() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(),
            pullRequest: nil,
            now: Self.now
        )

        #expect(card.state == "No pull request yet")
        #expect(card.detail == "Nothing has changed on this branch yet")
        #expect(card.status == .clean)
        #expect(card.diff == nil)
    }

    @Test("An open pull request takes the bold line and brings its number")
    func openPullRequest() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(name: "Workspace name", additions: 40, changedFiles: 2),
            pullRequest: pullRequest(
                title: "Answer a page's questions", checks: .passing,
                checksSummary: "12 checks passed"
            ),
            now: Self.now
        )

        #expect(card.title == "Answer a page's questions")
        #expect(card.state == "Ready to merge")
        #expect(card.detail == "12 checks passed")
        #expect(card.status == .checksPassed)
        #expect(card.pullRequest?.number == 362)
    }

    @Test("Failing checks put the count behind the state rather than in place of it")
    func failingChecks() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 42, deletions: 9, changedFiles: 3),
            pullRequest: pullRequest(
                checks: .failing, checksSummary: "1 of 12 required checks failed"
            ),
            now: Self.now
        )

        #expect(card.state == "Checks failing")
        #expect(card.detail == "1 of 12 required checks failed")
        #expect(card.status == .checksFailing)
    }

    @Test("A conflicted branch is not marked with the checks it happens to have passed")
    func conflictsBeatTheRollup() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 42, changedFiles: 3),
            pullRequest: pullRequest(
                mergeable: "CONFLICTING", checks: .passing, checksSummary: "12 checks passed"
            ),
            now: Self.now
        )

        #expect(card.state == "Merge conflicts")
        #expect(card.detail == "This branch conflicts with the base branch")
        #expect(card.status == .conflicted)
    }

    @Test("A rollup summary equal to the state is not repeated under it")
    func detailThatRepeatsTheState() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 42, changedFiles: 1),
            pullRequest: pullRequest(checks: .failing, checksSummary: "Checks failing"),
            now: Self.now
        )

        #expect(card.state == "Checks failing")
        #expect(card.detail == nil)
    }

    @Test("A merged pull request says so and has nothing to add")
    func merged() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(),
            pullRequest: pullRequest(
                number: 23, state: "MERGED", checks: .passing, checksSummary: "12 checks passed"
            ),
            now: Self.now
        )

        #expect(card.state == "Merged")
        #expect(card.status == .merged)
        #expect(card.detail == nil)
        #expect(card.pullRequest?.number == 23)
    }

    @Test("Local work takes the headline, and the mark goes with it")
    func localWorkTakesTheHeadline() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 12, deletions: 2, changedFiles: 2),
            pullRequest: pullRequest(checks: .passing, checksSummary: "12 checks passed"),
            localWork: LocalWork(modifiedFiles: 2, unpushedCommits: 1),
            now: Self.now
        )

        #expect(card.state == "Local changes")
        #expect(card.detail == "2 files to commit, 1 commit to push")
        #expect(card.status == .changed)
    }

    @Test("Local work over failing checks is added to the detail, not put in front of it")
    func localWorkUnderFailingChecks() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 12, changedFiles: 1),
            pullRequest: pullRequest(
                checks: .failing, checksSummary: "1 of 12 required checks failed"
            ),
            localWork: LocalWork(modifiedFiles: 1),
            now: Self.now
        )

        #expect(card.state == "Checks failing")
        #expect(card.detail == "1 of 12 required checks failed, 1 file to commit")
        #expect(card.status == .checksFailing)
    }

    @Test("An unread turn does not take the mark from the pull request")
    func unreadDoesNotTakeTheMark() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(additions: 5, changedFiles: 1, unread: true),
            pullRequest: pullRequest(checks: .passing, checksSummary: "12 checks passed"),
            now: Self.now
        )

        #expect(card.status == .checksPassed)
        #expect(card.state == "Ready to merge")
    }

    @Test("The branch verdict matches the row's whenever no agent is involved")
    func agreesWithTheRowWhenNothingIsRunning() {
        let subject = workspace(additions: 42, deletions: 9, changedFiles: 3)
        let request = pullRequest(checks: .pending, checksSummary: "3 of 12 checks running")

        #expect(
            WorkspaceStatus.ofBranch(workspace: subject, pullRequest: request)
                == WorkspaceStatus.resolve(
                    workspace: subject, isRunning: false, pullRequest: request
                )
        )
    }

    @Test("An empty pull request title falls back to the workspace's name")
    func emptyTitleFallsBack() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(name: "Answer a review support question"),
            pullRequest: pullRequest(title: "   "),
            now: Self.now
        )

        #expect(card.title == "Answer a review support question")
    }

    @Test("The age is the same phrase the rest of the app uses")
    func age() {
        let card = WorkspaceHoverCard.pullRequestBand(
            workspace: workspace(lastActivityAt: Self.now.addingTimeInterval(-6 * 86_400)),
            pullRequest: nil,
            now: Self.now
        )

        #expect(card.age == "6d ago")
    }
}
