import Foundation
import Testing
@testable import Core

@Suite("Pull request ownership")
struct PullRequestOwnershipTests {
    private func pullRequest(
        number: Int = 371,
        state: String = "MERGED",
        closedAt: Date? = nil
    ) -> PullRequest {
        PullRequest(
            number: number,
            title: "Update composer.json",
            url: "https://github.com/akira-io/example/pull/\(number)",
            state: state,
            branch: "update-composer-json",
            closedAt: closedAt
        )
    }

    private let started = Date(timeIntervalSince1970: 2_000_000)

    @Test("A pull request that ended before the workspace existed belongs to an earlier branch of the same name")
    func rejectsAPullRequestFromAnEarlierLife() {
        let stale = pullRequest(closedAt: started.addingTimeInterval(-86_400))
        #expect(
            PullRequestOwnership.belongs(stale, toWorkspaceStartedAt: started, checkedOutAs: nil)
                == false
        )
    }

    @Test("An open pull request is always this branch's, because GitHub allows only one per head")
    func acceptsAnOpenPullRequest() {
        let open = pullRequest(state: "OPEN", closedAt: nil)
        #expect(PullRequestOwnership.belongs(open, toWorkspaceStartedAt: started, checkedOutAs: nil))
    }

    @Test("A pull request this workspace opened and then merged is still this workspace's")
    func acceptsAPullRequestMergedAfterwards() {
        let merged = pullRequest(closedAt: started.addingTimeInterval(3_600))
        #expect(PullRequestOwnership.belongs(merged, toWorkspaceStartedAt: started, checkedOutAs: nil))
    }

    @Test("A worktree checked out from a pull request keeps it, however long ago it merged")
    func keepsTheCheckedOutPullRequest() {
        let merged = pullRequest(closedAt: started.addingTimeInterval(-604_800))
        #expect(
            PullRequestOwnership.belongs(merged, toWorkspaceStartedAt: started, checkedOutAs: 371)
        )
    }

    @Test("A different pull request than the one checked out is somebody else's")
    func rejectsAnotherNumberThanTheOneCheckedOut() {
        let open = pullRequest(number: 412, state: "OPEN", closedAt: nil)
        #expect(
            PullRequestOwnership.belongs(open, toWorkspaceStartedAt: started, checkedOutAs: 371)
                == false
        )
    }

    @Test("gh's closedAt is read, and an open pull request has none")
    func decodesClosedAt() throws {
        let merged = try GitHub.decodePullRequest(from: Data("""
        {"number":14207,"state":"MERGED","closedAt":"2026-08-20T15:59:43Z",
         "headRefName":"tidy-dev-diagnose-issue-triage"}
        """.utf8))
        #expect(merged.closedAt == ISO8601DateFormatter().date(from: "2026-08-20T15:59:43Z"))

        let open = try GitHub.decodePullRequest(from: Data("""
        {"number":14300,"state":"OPEN","closedAt":null,"headRefName":"wip"}
        """.utf8))
        #expect(open.closedAt == nil)
    }

    @Test("A gh old enough not to report closedAt leaves the pull request alone")
    func toleratesAnOlderGH() throws {
        let decoded = try GitHub.decodePullRequest(from: Data("""
        {"number":7,"state":"MERGED","headRefName":"wip"}
        """.utf8))
        #expect(decoded.closedAt == nil)
        #expect(PullRequestOwnership.belongs(decoded, toWorkspaceStartedAt: started, checkedOutAs: nil))
    }
}

@Suite("What a worktree was checked out from", .tags(.git), .scratchDirectory)
struct CheckedOutPullRequestTests {
    @Test("gh pr checkout's own record is read back, and an ordinary branch has none")
    func readsThePullRequestFromGitConfig() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        #expect(await Git.checkedOutPullRequest(branch: "main", worktree: repo.path) == nil)

        try await Shell.check(
            "git", ["config", "branch.main.merge", "refs/pull/371/head"], cwd: repo.path
        )
        #expect(await Git.checkedOutPullRequest(branch: "main", worktree: repo.path) == 371)

        try await Shell.check(
            "git", ["config", "branch.main.merge", "refs/heads/main"], cwd: repo.path
        )
        #expect(await Git.checkedOutPullRequest(branch: "main", worktree: repo.path) == nil)
    }
}
