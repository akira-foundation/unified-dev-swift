import Foundation
import Testing
@testable import Core

@Suite("A branch pushed to a fork without an upstream", .tags(.git), .scratchDirectory)
struct UnpublishedForkHeadTests {
    private static let branch = "tarefa-corrigir-achado-08-da"

    private struct Listed {
        var number = 22
        var owner = "kidiatoliny"
        var repository = "kriol"
        var commit: String
    }

    private static func pullRequest(_ number: Int, head: String = branch) -> String {
        #"{"number":\#(number),"title":"Pin the Windows toolchain","url":"https://github.com/kriol-lang/kriol/pull/\#(number)","state":"MERGED","isDraft":false,"mergeable":"UNKNOWN","reviewDecision":null,"headRefName":"\#(head)","statusCheckRollup":[],"closedAt":"2026-10-29T12:34:27Z"}"#
    }

    private static func listing(_ entries: [Listed]) -> String {
        let rows = entries.map {
            #"{"number":\#($0.number),"closedAt":"2026-10-29T12:34:27Z","headRefOid":"\#($0.commit)","headRepository":{"name":"\#($0.repository)"},"headRepositoryOwner":{"login":"\#($0.owner)"}}"#
        }
        return "[" + rows.joined(separator: ",") + "]"
    }

    private static func answer(
        _ entries: [Listed], head: String = branch, asked: AskedArguments? = nil
    ) -> @Sendable ([String], String?) async throws -> ShellResult {
        let listed = listing(entries)
        let numbers = entries.map(\.number)
        return { arguments, _ in
            await asked?.record(arguments)
            if arguments.starts(with: ["pr", "list"]) {
                return ShellResult(status: 0, stdout: listed, stderr: "")
            }
            if arguments.count > 2, arguments.starts(with: ["pr", "view"]),
               let number = Int(arguments[2]), numbers.contains(number) {
                return ShellResult(status: 0, stdout: pullRequest(number, head: head), stderr: "")
            }
            return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch \"\(branch)\"")
        }
    }

    private static func repo(fork: Bool = true) async throws -> TempRepo {
        let repo = try await TempRepo()
        try await git(["remote", "add", "origin", "https://github.com/kriol-lang/kriol"], in: repo)
        if fork { try await git(["remote", "add", "fork", "git@github.com:kidiatoliny/kriol.git"], in: repo) }
        try await git(["update-ref", "refs/remotes/origin/main", "HEAD"], in: repo)
        try await git(["checkout", "-q", "-b", branch], in: repo)
        try await git(["config", "branch.\(branch).gh-merge-base", "main"], in: repo)
        try await git(["config", "branch.\(branch).unifieddev-base-remote", "origin"], in: repo)
        return repo
    }

    @discardableResult
    private static func git(_ arguments: [String], in repo: TempRepo) async throws -> String {
        try await Shell.check("git", arguments, cwd: repo.path).trimmed
    }

    private static func commit(in repo: TempRepo) async throws -> String {
        try await git(["commit", "-q", "--allow-empty", "-m", "pin"], in: repo)
        return try await git(["rev-parse", "HEAD"], in: repo)
    }

    private static func lookUp(
        in repo: TempRepo, maxAge: Duration = .zero,
        _ answer: @escaping @Sendable ([String], String?) async throws -> ShellResult
    ) async throws -> PullRequestSnapshot? {
        try await GitHub.$commandOverride.withValue(answer) {
            try await GitHub.snapshot(forBranch: branch, worktree: repo.path, base: "main", maxAge: maxAge)
        }
    }

    @Test("the merged pull request of the fork is found by the commit it was pushed with")
    func findsTheForkPullRequest() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let found = try await Self.lookUp(in: repo, Self.answer([Listed(commit: tip)]))

        #expect(found?.pullRequest.number == 22)
        #expect(found?.pullRequest.state == "MERGED")
    }

    @Test("a branch that moved on past what it pushed still owns the pull request")
    func followsABranchThatMovedOn() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let pushed = try await Self.commit(in: repo)
        _ = try await Self.commit(in: repo)

        let found = try await Self.lookUp(in: repo, Self.answer([Listed(commit: pushed)]))

        #expect(found?.pullRequest.number == 22)
    }

    @Test("an old pull request whose head is already in the base is not adopted by a new branch")
    func refusesAHeadTheBaseHolds() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let base = try await Self.git(["rev-parse", "refs/remotes/origin/main"], in: repo)
        _ = try await Self.commit(in: repo)

        let found = try await Self.lookUp(in: repo, Self.answer([Listed(commit: base)]))

        #expect(found == nil)
    }

    @Test("a pull request whose head commit this branch does not hold is not adopted")
    func refusesAForeignCommit() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        _ = try await Self.commit(in: repo)
        try await Self.git(["checkout", "-q", "-b", "elsewhere"], in: repo)
        let elsewhere = try await Self.commit(in: repo)
        try await Self.git(["checkout", "-q", Self.branch], in: repo)

        let found = try await Self.lookUp(in: repo, Self.answer([Listed(commit: elsewhere)]))

        #expect(found == nil)
    }

    @Test("of two pull requests the branch holds, the newest is the one shown")
    func prefersTheNewest() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let found = try await Self.lookUp(
            in: repo, Self.answer([Listed(number: 20, commit: tip), Listed(number: 22, commit: tip)])
        )

        #expect(found?.pullRequest.number == 22)
    }

    @Test("the fork is recognised whatever case GitHub spells its owner in")
    func ignoresTheOwnersCase() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let found = try await Self.lookUp(in: repo, Self.answer([Listed(owner: "KidiAtoliny", commit: tip)]))

        #expect(found?.pullRequest.number == 22)
    }

    @Test("a pull request from a repository no remote names is not adopted", arguments: [
        ("stranger", "kriol"), ("kidiatoliny", "another-kriol"), ("kriol-lang", "kriol"),
    ])
    func refusesAnUnnamedRepository(owner: String, repository: String) async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let found = try await Self.lookUp(
            in: repo, Self.answer([Listed(owner: owner, repository: repository, commit: tip)])
        )

        #expect(found == nil)
    }

    @Test("a pull request that turns out to have another head is not adopted")
    func rechecksTheHeadItViews() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let found = try await Self.lookUp(in: repo, Self.answer([Listed(commit: tip)], head: "something-else"))

        #expect(found == nil)
    }

    @Test("a branch that tracks a remote is left to the lookup that reads its upstream", arguments: [
        "remote", "pushremote",
    ])
    func leavesATrackedBranchAlone(key: String) async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)
        try await Self.git(["config", "branch.\(Self.branch).\(key)", "fork"], in: repo)

        let asked = AskedArguments()
        _ = try await Self.lookUp(in: repo, Self.answer([Listed(commit: tip)], asked: asked))

        #expect(await !asked.all.contains { $0.starts(with: ["pr", "list"]) })
    }

    @Test("a fork listing gh cannot answer leaves the branch without a pull request rather than failing")
    func toleratesAFailedListing() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        _ = try await Self.commit(in: repo)

        let found = try await Self.lookUp(in: repo) { arguments, _ in
            if arguments.starts(with: ["pr", "list"]) { throw GitHubError("timed out") }
            return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch")
        }

        #expect(found == nil)
    }

    @Test("a fork listing that failed is asked again rather than remembered as no pull request")
    func doesNotRememberAFailedListing() async throws {
        let repo = try await Self.repo()
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let failed = try await Self.lookUp(in: repo, maxAge: .seconds(300)) { arguments, _ in
            if arguments.starts(with: ["pr", "list"]) { throw GitHubError("timed out") }
            return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch")
        }
        let retried = try await Self.lookUp(in: repo, maxAge: .seconds(300), Self.answer([Listed(commit: tip)]))

        #expect(failed == nil)
        #expect(retried?.pullRequest.number == 22)
    }

    @Test("a repository with no fork remote asks gh nothing more")
    func asksNothingWithoutAFork() async throws {
        let repo = try await Self.repo(fork: false)
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)

        let asked = AskedArguments()
        let found = try await Self.lookUp(in: repo, Self.answer([Listed(commit: tip)], asked: asked))

        #expect(found == nil)
        #expect(await !asked.all.contains { $0.starts(with: ["pr", "list"]) })
    }

    @Test("a fork remote added after a miss is asked about rather than served from the cache")
    func cacheFollowsTheForkRemotes() async throws {
        let repo = try await Self.repo(fork: false)
        defer { repo.cleanUp() }
        let tip = try await Self.commit(in: repo)
        let answer = Self.answer([Listed(commit: tip)])

        let before = try await Self.lookUp(in: repo, maxAge: .seconds(300), answer)
        try await Self.git(["remote", "add", "fork", "git@github.com:kidiatoliny/kriol.git"], in: repo)
        let after = try await Self.lookUp(in: repo, maxAge: .seconds(300), answer)

        #expect(before == nil)
        #expect(after?.pullRequest.number == 22)
    }
}
