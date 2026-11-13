import Testing
import Foundation
@testable import Core

@Suite("When a merged pull request would archive a worktree that still has work in flight")
struct MergeArchiveInFlightTests {
    @Test("a merge with nothing else in flight raises no objection")
    func nothingInFlight() {
        let branches = [
            MergeArchiveInFlight.standing(
                branch: "fix/579-a", pullRequests: [BranchPullRequest(number: 579, isOpen: false)], unpushedCommits: 0
            ),
            MergeArchiveInFlight.standing(branch: "develop", pullRequests: [], unpushedCommits: 0),
        ]
        #expect(MergeArchiveInFlight.objection(branches) == nil)
        #expect(MergeArchiveInFlight.objection([]) == nil)
    }

    @Test("other open pull requests from the same worktree are named to the owner")
    func openPullRequestsObject() {
        let branches = [
            MergeArchiveInFlight.standing(
                branch: "fix/580-b", pullRequests: [BranchPullRequest(number: 580, isOpen: true)], unpushedCommits: 0
            ),
            MergeArchiveInFlight.standing(
                branch: "fix/579-a", pullRequests: [BranchPullRequest(number: 579, isOpen: true)], unpushedCommits: 3
            ),
        ]
        #expect(MergeArchiveInFlight.objection(branches) == "#579 and #580 are still open.")
        #expect(MergeArchiveInFlight.objection(Array(branches.prefix(1))) == "#580 is still open.")
    }

    @Test("a local branch with commits not on its remote is named to the owner")
    func unpushedBranchObjects() {
        let one = MergeArchiveInFlight.standing(branch: "fix/453-local", pullRequests: [], unpushedCommits: 1)
        let two = MergeArchiveInFlight.standing(branch: "fix/454-local", pullRequests: [], unpushedCommits: 2)
        let open = MergeArchiveInFlight.standing(
            branch: "fix/583-c", pullRequests: [BranchPullRequest(number: 583, isOpen: true)], unpushedCommits: 0
        )
        #expect(MergeArchiveInFlight.objection([one]) == "fix/453-local has 1 commit that is not pushed.")
        #expect(MergeArchiveInFlight.objection([open, one, two]) == """
            #583 is still open. fix/453-local has 1 commit that is not pushed. \
            fix/454-local has 2 commits that are not pushed.
            """)
    }

    @Test("the branches of a worktree come from its own checkouts, without the merged one or deleted ones")
    func candidatesFromReflog() {
        let reflog = """
            checkout: moving from fix/580-b to fix/586-d
            commit: something
            checkout: moving from develop to fix/580-b
            checkout: moving from 1234abcd to develop
            """
        let checkedOut = MergeArchiveInFlight.checkedOutBranches(reflogSubjects: reflog)
        #expect(checkedOut == ["fix/586-d", "fix/580-b", "develop", "1234abcd"])
        #expect(MergeArchiveInFlight.candidates(
            checkedOut: checkedOut,
            current: "fix/586-d",
            localBranches: ["fix/586-d", "fix/580-b", "develop", "someone-elses"],
            merged: "fix/586-d"
        ) == ["fix/580-b", "develop"])
    }

    @Test("reading a real worktree objects to an open pull request and to an unpushed branch, not to a merged one")
    func readsARealWorktree() async throws {
        let fixture = try await Fixture()
        defer { fixture.cleanUp() }
        try await fixture.branch("fix/579-open", push: true)
        try await fixture.branch("fix/560-squashed", push: false)
        let squashedTip = try await fixture.tip()
        try await fixture.branch("fix/453-local", push: false)
        try await fixture.branch("fix/586-merged", push: true)

        let lookup: MergeArchiveInFlightRead.PullRequestLookup = { branch, _ in
            switch branch {
            case "fix/579-open": [BranchPullRequest(number: 579, isOpen: true)]
            case "fix/560-squashed": [BranchPullRequest(number: 560, isOpen: false, headCommit: squashedTip)]
            case "fix/586-merged": [BranchPullRequest(number: 586, isOpen: false)]
            default: []
            }
        }
        let objection = await MergeArchiveInFlightRead.objection(
            worktree: fixture.repo.path, mergedBranch: "fix/586-merged", lookup: lookup
        )
        #expect(objection == "#579 is still open. fix/453-local has 1 commit that is not pushed.")

        try await fixture.git(["branch", "-D", "fix/453-local"])
        let closedLookup: MergeArchiveInFlightRead.PullRequestLookup = { branch, worktree in
            try await lookup(branch, worktree).map { BranchPullRequest(number: $0.number, isOpen: false, headCommit: $0.headCommit) }
        }
        #expect(await MergeArchiveInFlightRead.objection(
            worktree: fixture.repo.path, mergedBranch: nil, lookup: closedLookup
        ) == nil)
    }

    @Test("gh's answer for a branch reads open and merged pull requests with their heads")
    func decodesGitHubAnswer() throws {
        let json = #"[{"number":579,"state":"OPEN","headRefOid":"abc"},{"number":560,"state":"MERGED"},{"state":"OPEN"}]"#
        #expect(try GitHub.decodeBranchPullRequests(from: Data(json.utf8)) == [
            BranchPullRequest(number: 579, isOpen: true, headCommit: "abc"),
            BranchPullRequest(number: 560, isOpen: false),
        ])
    }

    @Test("a lookup that fails holds the archive back rather than guessing")
    func failedLookupObjects() async throws {
        let fixture = try await Fixture()
        defer { fixture.cleanUp() }
        try await fixture.branch("fix/579-open", push: true)
        try await fixture.branch("fix/586-merged", push: true)
        let objection = await MergeArchiveInFlightRead.objection(
            worktree: fixture.repo.path, mergedBranch: "fix/586-merged"
        ) { _, _ in throw GitHubError("offline") }
        #expect(objection?.contains("could not read the other branches") == true)
    }

    private struct Fixture {
        let repo: TempRepo
        let remote: String

        init() async throws {
            repo = try await TempRepo()
            remote = TestScratch.unique("unifieddev-remote")
            try FileManager.default.createDirectory(atPath: remote, withIntermediateDirectories: true)
            try await Shell.check("git", ["init", "-q", "--bare"], cwd: remote)
            try await git(["remote", "add", "origin", remote])
            try await git(["push", "-q", "origin", "main"])
        }

        func branch(_ name: String, push: Bool) async throws {
            try await git(["checkout", "-q", "-b", name, "main"])
            try repo.write("\(name).txt", name)
            try await repo.commit(name)
            if push { try await git(["push", "-q", "origin", name]) }
        }

        func tip() async throws -> String {
            try await Shell.check("git", ["rev-parse", "HEAD"], cwd: repo.path).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func git(_ arguments: [String]) async throws {
            try await Shell.check("git", arguments, cwd: repo.path)
        }

        func cleanUp() {
            repo.cleanUp()
            try? FileManager.default.removeItem(atPath: remote)
        }
    }
}
