import Foundation
import Testing
@testable import Core

@Suite("Which branch a pull request is looked up by")
struct PullRequestHeadTests {
    @Test("The branch the worktree is on now wins over the one recorded at creation")
    func prefersTheCheckedOutBranch() {
        #expect(
            PullRequestHead.branch(
                recorded: "unifieddev/preview-crash",
                checkedOut: "fix/issue-2069-transactional-mail-admin-preview",
                base: "main"
            ) == "fix/issue-2069-transactional-mail-admin-preview"
        )
    }

    @Test("A detached HEAD leaves the recorded branch as the only name there is")
    func fallsBackWhenDetached() {
        #expect(
            PullRequestHead.branch(recorded: "unifieddev/preview-crash", checkedOut: nil, base: "main")
                == "unifieddev/preview-crash"
        )
        #expect(
            PullRequestHead.branch(recorded: "unifieddev/preview-crash", checkedOut: "  ", base: "main")
                == "unifieddev/preview-crash"
        )
    }

    @Test("A worktree standing on the base branch is not asked about")
    func refusesTheBaseBranch() {
        #expect(
            PullRequestHead.branch(recorded: "unifieddev/preview-crash", checkedOut: "main", base: "main")
                == "unifieddev/preview-crash"
        )
    }

    @Test("A row with no branch name in it is not a name to prefer")
    func toleratesAnEmptyRecord() {
        #expect(PullRequestHead.branch(recorded: "", checkedOut: "main", base: "main") == "main")
        #expect(PullRequestHead.branch(recorded: "", checkedOut: nil, base: "main") == "")
    }
}

@Suite("The branch gh is asked about", .tags(.git), .scratchDirectory)
struct PullRequestHeadBranchTests {
    @Test("A worktree the agent moved to a new branch is looked up under that branch")
    func readsTheBranchOffDisk() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let workspace = Workspace(
            repoID: RepoID.new(),
            name: "Preview crash",
            branch: "unifieddev/preview-crash",
            path: repo.path,
            baseBranch: "main"
        )

        #expect(await GitHub.headBranch(of: workspace) == "unifieddev/preview-crash")

        try await Shell.check(
            "git", ["checkout", "-q", "-b", "fix/issue-2069-preview"], cwd: repo.path
        )
        #expect(await GitHub.headBranch(of: workspace) == "fix/issue-2069-preview")
    }
}

@Suite("The head gh is asked about")
struct PullRequestHeadSelectorTests {
    private let shared = [
        "remote.origin.url": "https://github.com/kriol-lang/kriol",
        "remote.fork.url": "https://github.com/kidiatoliny/kriol.git",
        "branch.main.remote": "origin",
        "branch.main.merge": "refs/heads/main",
    ]

    private func context(on branch: String, _ extra: [String: String] = [:]) -> GitRepositoryContext {
        GitRepositoryContext.resolve(
            config: shared.merging(extra) { _, new in new },
            base: "main",
            branch: branch,
            baseIsBranchName: true
        )
    }

    @Test("a branch pushed under another name is asked about under that name and its owner")
    func namesThatDiffer() {
        let resolved = context(on: "tarefa-corrigir-achado-06-da", [
            "branch.tarefa-corrigir-achado-06-da.remote": "fork",
            "branch.tarefa-corrigir-achado-06-da.merge": "refs/heads/fix/windows-test-step-exit",
            "branch.tarefa-corrigir-achado-06-da.unifieddev-base-remote": "origin",
        ])
        #expect(resolved.headBranch == "fix/windows-test-step-exit")
        #expect(PullRequestHead.selector(in: resolved) == "kidiatoliny:fix/windows-test-step-exit")
    }

    @Test("a branch pushed to the base repository under its own name is asked about plainly")
    func namesThatMatch() {
        let resolved = context(on: "feature", [
            "branch.feature.remote": "origin",
            "branch.feature.merge": "refs/heads/feature",
        ])
        #expect(resolved.headBranch == "feature")
        #expect(PullRequestHead.selector(in: resolved) == "feature")
    }

    @Test("a branch on a fork carries its owner even when the two names are the same")
    func aFork() {
        let resolved = context(on: "akira/peaceful-taussig-23d36e", [
            "branch.akira/peaceful-taussig-23d36e.remote": "fork",
            "branch.akira/peaceful-taussig-23d36e.merge": "refs/heads/akira/peaceful-taussig-23d36e",
            "branch.akira/peaceful-taussig-23d36e.unifieddev-base-remote": "origin",
        ])
        #expect(PullRequestHead.selector(in: resolved) == "kidiatoliny:akira/peaceful-taussig-23d36e")
    }

    @Test("a branch with no upstream is asked about under the only name there is")
    func noUpstream() {
        let resolved = context(on: "spike")
        #expect(resolved.headBranch == "spike")
        #expect(PullRequestHead.selector(in: resolved) == "spike")
    }

    @Test("a detached head names nothing to ask about")
    func detachedHead() {
        #expect(PullRequestHead.selector(in: context(on: "HEAD")) == nil)
    }

    @Test("a branch that merely tracks its base is asked about under its own name")
    func tracksTheBase() {
        let resolved = context(on: "feature", [
            "branch.feature.remote": "origin",
            "branch.feature.merge": "refs/heads/main",
        ])
        #expect(resolved.headBranch == "feature")
        #expect(PullRequestHead.selector(in: resolved) == "feature")
    }

    @Test("a branch fetched from the base and pushed to a fork carries the fork's owner")
    func triangularPublication() {
        let resolved = context(on: "feature", [
            "branch.feature.remote": "origin",
            "branch.feature.merge": "refs/heads/feature",
            "branch.feature.pushremote": "fork",
        ])
        #expect(PullRequestHead.selector(in: resolved) == "kidiatoliny:feature")
    }

    @Test("a head on another host lends no owner to the question")
    func anotherHost() {
        let resolved = context(on: "feature", [
            "remote.elsewhere.url": "https://gitlab.com/stranger/kriol.git",
            "branch.feature.remote": "elsewhere",
            "branch.feature.merge": "refs/heads/feature",
            "branch.feature.unifieddev-base-remote": "origin",
        ])
        #expect(PullRequestHead.selector(in: resolved) == "feature")
    }

    @Test("a head of digits alone names nothing, because gh would read it as a number")
    func numericHead() {
        let resolved = context(on: "work", [
            "branch.work.remote": "origin",
            "branch.work.merge": "refs/heads/2069",
        ])
        #expect(resolved.headBranch == "2069")
        #expect(PullRequestHead.selector(in: resolved) == nil)
    }

    @Test("a head of digits on a fork is named, because the owner makes it a branch")
    func numericHeadOnAFork() {
        let resolved = context(on: "work", [
            "branch.work.remote": "fork",
            "branch.work.merge": "refs/heads/2069",
            "branch.work.unifieddev-base-remote": "origin",
        ])
        #expect(PullRequestHead.selector(in: resolved) == "kidiatoliny:2069")
    }

    @Test("a pull request checkout tracks no head branch to ask about")
    func pullRequestCheckout() {
        let resolved = context(on: "pr-15", [
            "branch.pr-15.remote": "origin",
            "branch.pr-15.merge": "refs/pull/15/head",
        ])
        #expect(resolved.headBranch == "pr-15")
    }
}

@Suite("What gh is asked for a branch pushed under another name", .tags(.git), .scratchDirectory)
struct PullRequestHeadLookupTests {
    private static let listing = #"[{"number":15,"closedAt":"2026-10-08T23:38:53Z","headRepositoryOwner":{"login":"kidiatoliny"}},{"number":16,"closedAt":null,"headRepositoryOwner":{"login":"stranger"}}]"#
    private static let merged = #"{"number":15,"title":"Fix the Windows test step","url":"https://github.com/kriol-lang/kriol/pull/15","state":"MERGED","isDraft":false,"mergeable":"UNKNOWN","reviewDecision":null,"headRefName":"fix/windows-test-step-exit","statusCheckRollup":[],"closedAt":"2026-10-08T23:38:53Z"}"#

    private static func forkedRepo() async throws -> TempRepo {
        let repo = try await TempRepo()
        try await Shell.check(
            "git", ["remote", "add", "origin", "https://github.com/kriol-lang/kriol"], cwd: repo.path
        )
        try await Shell.check(
            "git", ["remote", "add", "fork", "https://github.com/kidiatoliny/kriol.git"], cwd: repo.path
        )
        try await Shell.check("git", ["config", "branch.main.remote", "origin"], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.main.merge", "refs/heads/main"], cwd: repo.path)
        return repo
    }

    private static func track(
        _ branch: String, remote: String, merge: String, in repo: TempRepo
    ) async throws {
        try await Shell.check("git", ["checkout", "-q", "-b", branch], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.\(branch).remote", remote], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.\(branch).merge", merge], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.\(branch).gh-merge-base", "main"], cwd: repo.path)
        try await Shell.check(
            "git", ["config", "branch.\(branch).unifieddev-base-remote", "origin"], cwd: repo.path
        )
    }

    @Test("the merged pull request is found under the name the branch was pushed as")
    func asksForTheRemoteName() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track(
            "tarefa-corrigir-achado-06-da", remote: "fork",
            merge: "refs/heads/fix/windows-test-step-exit", in: repo
        )

        let asked = AskedArguments()
        let found = try await GitHub.$commandOverride.withValue({ arguments, _ in
            await asked.record(arguments)
            return ShellResult(status: 0, stdout: Self.merged, stderr: "")
        }) {
            try await GitHub.snapshot(
                forBranch: "tarefa-corrigir-achado-06-da", worktree: repo.path, maxAge: .zero
            )
        }

        let snapshot = try #require(found)
        #expect(snapshot.pullRequest.number == 15)
        #expect(snapshot.pullRequest.state == "MERGED")
        let arguments = try #require(await asked.first)
        #expect(arguments.contains("kidiatoliny:fix/windows-test-step-exit"))
        #expect(!arguments.contains("tarefa-corrigir-achado-06-da"))
        #expect(arguments.contains("github.com/kriol-lang/kriol"))
    }

    @Test("a branch pushed to the base repository under its own name is asked about as before")
    func asksForTheLocalName() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track("feature", remote: "origin", merge: "refs/heads/feature", in: repo)

        let asked = AskedArguments()
        _ = try await GitHub.$commandOverride.withValue({ arguments, _ in
            await asked.record(arguments)
            return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch \"feature\"")
        }) {
            try await GitHub.snapshot(forBranch: "feature", worktree: repo.path, maxAge: .zero)
        }

        let arguments = try #require(await asked.first)
        #expect(arguments.contains("feature"))
        #expect(!arguments.contains { $0.contains(":") })
    }

    @Test("the pull requests of a vanished branch are listed under the name it was pushed as")
    func listsTheRemoteName() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track(
            "tarefa-corrigir-achado-06-da", remote: "fork",
            merge: "refs/heads/fix/windows-test-step-exit", in: repo
        )
        try await Shell.check("git", ["checkout", "-q", "main"], cwd: repo.path)
        try await Shell.check(
            "git", ["update-ref", "-d", "refs/heads/tarefa-corrigir-achado-06-da"], cwd: repo.path
        )
        #expect(await !Git.branchExists("tarefa-corrigir-achado-06-da", in: repo.path))

        let asked = AskedArguments()
        let matches = try await GitHub.$commandOverride.withValue({ arguments, _ in
            await asked.record(arguments)
            return ShellResult(status: 0, stdout: Self.listing, stderr: "")
        }) {
            try await GitHub.pullRequestsWithHead("tarefa-corrigir-achado-06-da", worktree: repo.path)
        }

        #expect(matches.map(\.number) == [15])
        let arguments = try #require(await asked.first)
        let head = try #require(arguments.firstIndex(of: "--head").map { arguments[$0 + 1] })
        #expect(head == "fix/windows-test-step-exit")
    }

    @Test("a pull request of the same head name from another account is not adopted")
    func refusesAnotherOwner() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track(
            "tarefa-corrigir-achado-06-da", remote: "fork",
            merge: "refs/heads/fix/windows-test-step-exit", in: repo
        )

        let matches = try await GitHub.$commandOverride.withValue({ _, _ in
            ShellResult(status: 0, stdout: Self.listing, stderr: "")
        }) {
            try await GitHub.pullRequestsWithHead("tarefa-corrigir-achado-06-da", worktree: repo.path)
        }
        #expect(matches.map(\.number) == [15])
    }

    @Test("a head resolved from new configuration is asked about again rather than served from the cache")
    func cacheFollowsTheHead() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track(
            "tarefa-corrigir-achado-06-da", remote: "fork",
            merge: "refs/heads/fix/windows-test-step-exit", in: repo
        )

        let asked = AskedArguments()
        let answer: @Sendable ([String], String?) async throws -> ShellResult = { arguments, _ in
            await asked.record(arguments)
            return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch")
        }
        _ = try await GitHub.$commandOverride.withValue(answer) {
            try await GitHub.snapshot(
                forBranch: "tarefa-corrigir-achado-06-da", worktree: repo.path, maxAge: .seconds(300)
            )
        }
        try await Shell.check(
            "git", ["config", "branch.tarefa-corrigir-achado-06-da.merge", "refs/heads/fix/another-step"],
            cwd: repo.path
        )
        _ = try await GitHub.$commandOverride.withValue(answer) {
            try await GitHub.snapshot(
                forBranch: "tarefa-corrigir-achado-06-da", worktree: repo.path, maxAge: .seconds(300)
            )
        }

        let heads = await asked.all.compactMap { $0.dropFirst(2).first }
        #expect(heads == ["kidiatoliny:fix/windows-test-step-exit", "kidiatoliny:fix/another-step"])
    }

    @Test("a pull request checked out by number is found by that number")
    func findsAPullRequestCheckout() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["checkout", "-q", "-b", "pr-15"], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.pr-15.remote", "origin"], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.pr-15.merge", "refs/pull/15/head"], cwd: repo.path)

        let asked = AskedArguments()
        let found = try await GitHub.$commandOverride.withValue({ arguments, _ in
            await asked.record(arguments)
            guard arguments.dropFirst(2).first == "15" else {
                return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch")
            }
            return ShellResult(status: 0, stdout: Self.merged, stderr: "")
        }) {
            try await GitHub.snapshot(forBranch: "pr-15", worktree: repo.path, maxAge: .zero)
        }

        #expect(found?.pullRequest.number == 15)
        #expect(await asked.all.count == 2)
    }

    @Test("a pull request whose head is not the one asked for is not the workspace's")
    func refusesAnotherHead() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track("feature", remote: "origin", merge: "refs/heads/feature", in: repo)

        let found = try await GitHub.$commandOverride.withValue({ _, _ in
            ShellResult(status: 0, stdout: Self.merged, stderr: "")
        }) {
            try await GitHub.snapshot(forBranch: "feature", worktree: repo.path, maxAge: .zero)
        }
        #expect(found == nil)
    }

    @Test("a pull request just created is read even when the head it was created under is not found")
    func fallsBackAfterCreating() async throws {
        let repo = try await Self.forkedRepo()
        defer { repo.cleanUp() }
        try await Self.track("feature", remote: "origin", merge: "refs/heads/feature", in: repo)

        let asked = AskedArguments()
        let created = try await GitHub.$commandOverride.withValue({ arguments, _ in
            await asked.record(arguments)
            if arguments.dropFirst().first == "create" { return ShellResult(status: 0, stdout: "", stderr: "") }
            guard arguments.dropFirst(2).first?.hasPrefix("-") ?? true else {
                return ShellResult(status: 1, stdout: "", stderr: "no pull requests found for branch \"feature\"")
            }
            return ShellResult(status: 0, stdout: Self.merged, stderr: "")
        }) {
            try await GitHub.createPullRequest(
                worktree: repo.path, base: "main", title: "Fix the Windows test step", body: "", draft: false
            )
        }

        #expect(created.number == 15)
        #expect(await asked.all.count == 3)
    }
}

private actor AskedArguments {
    private(set) var all: [[String]] = []

    var first: [String]? { all.first }

    func record(_ arguments: [String]) {
        all.append(arguments)
    }
}
