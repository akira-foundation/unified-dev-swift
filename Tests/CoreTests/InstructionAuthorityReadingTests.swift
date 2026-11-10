import Foundation
import Testing
@testable import Core

@Suite("What the decision about a checkout is read from", .serialized, .tags(.git), .scratchDirectory)
struct InstructionAuthorityReadingTests {
    private static let branch = "feat/own-work"

    private static func pullRequest(
        in repo: TempRepo, author: String? = "owner", branch: String = branch
    ) async throws -> PullRequest {
        PullRequest(
            number: 7, title: "Work", url: "https://github.example/akira/app/pull/7", state: "OPEN",
            branch: branch, baseBranch: "develop", headCommit: try await Git.headSHA(of: repo.path),
            author: author, isFromFork: false
        )
    }

    private static func view(fork: String, author: String) -> String {
        #"{"number":7,"title":"Work","url":"https://example/7","state":"OPEN","headRefName":"\#(branch)","statusCheckRollup":[],"isCrossRepository":\#(fork),"author":\#(author)}"#
    }

    private static func snapshot(
        _ json: String
    ) async throws -> PullRequest? {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let found = try await GitHub.$commandOverride.withValue({ _, _ in
            ShellResult(status: 0, stdout: json, stderr: "")
        }) {
            try await GitHub.snapshot(forNumber: 7, worktree: repo.path, maxAge: .zero)
        }
        return found?.pullRequest
    }

    @Test("gh is asked for the origin and the author, with or without the checks")
    func asksGHForTheOrigin() {
        for fields in [GitHub.fields, GitHub.fieldsWithoutChecks] {
            let names = fields.split(separator: ",")
            #expect(names.contains("isCrossRepository"))
            #expect(names.contains("author"))
        }
    }

    @Test("the origin and the author are read from gh's answer")
    func readsOriginFromGH() async throws {
        let found = try await Self.snapshot(Self.view(fork: "true", author: #"{"login":"someone"}"#))

        #expect(found?.isFromFork == true)
        #expect(found?.author == "someone")
    }

    @Test("an answer without an author leaves it unknown")
    func missingAuthorStaysUnknown() async throws {
        let found = try await Self.snapshot(Self.view(fork: "false", author: "null"))

        #expect(found?.isFromFork == false)
        #expect(found?.author == nil)
    }

    @Test("a pull request remembered from before these fields decodes as unknown")
    func rememberedPullRequestIsUnknown() throws {
        let json = Data(#"{"number":7,"title":"Work","url":"u","state":"OPEN","isDraft":false,"checks":"none","checksSummary":"","branch":"b","baseBranch":"main"}"#.utf8)

        let decoded = try JSONDecoder().decode(PullRequest.self, from: json)

        #expect(decoded.isFromFork == nil)
        #expect(decoded.author == nil)
    }

    private static func workspace(_ repo: TempRepo, recorded: Int? = nil) -> Workspace {
        Workspace(
            repoID: .new(), name: "Work", branch: branch, path: repo.path,
            baseBranch: "main", pullRequestNumber: recorded
        )
    }

    private static func repoOnBranch() async throws -> TempRepo {
        let repo = try await TempRepo()
        try await Shell.check("git", ["remote", "add", "origin", "https://github.com/akira/app"], cwd: repo.path)
        try await Shell.check("git", ["checkout", "-q", "-b", branch], cwd: repo.path)
        return repo
    }

    private static func authority(
        for workspace: Workspace,
        pullRequest: PullRequest? = nil,
        wasRead: Bool = true,
        failure: GitHubReadFailure? = nil,
        viewer: ShellResult = ShellResult(status: 0, stdout: "owner\n", stderr: ""),
        asked: AskedArguments? = nil
    ) async -> InstructionAuthority {
        await GitHub.$commandOverride.withValue({ arguments, _ in
            await asked?.record(arguments)
            return viewer
        }) {
            await GitHub.instructionAuthority(
                for: workspace, pullRequest: pullRequest, hasReadPullRequest: wasRead, readFailure: failure
            )
        }
    }

    @Test("the account signed in to the pull request's own host decides whose it is")
    func readsTheViewerOnTheHost() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        let workspace = Self.workspace(repo)
        let asked = AskedArguments()

        let own = await Self.authority(
            for: workspace, pullRequest: try await Self.pullRequest(in: repo), asked: asked
        )
        let other = await Self.authority(
            for: workspace, pullRequest: try await Self.pullRequest(in: repo, author: "someone-else")
        )

        #expect(own == .project)
        #expect(other == .appOnly)
        #expect(await asked.all.contains(["api", "user", "--hostname", "github.example", "--jq", ".login"]))
    }

    @Test("a pull request whose address names no host has no account to compare with")
    func noHostIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        var pullRequest = try await Self.pullRequest(in: repo)
        pullRequest.url = ""

        #expect(await Self.authority(for: Self.workspace(repo), pullRequest: pullRequest) == .appOnly)
    }

    @Test("an account gh cannot name is doubt")
    func unreadableViewerIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        for viewer in [
            ShellResult(status: 1, stdout: "", stderr: "not logged in"),
            ShellResult(status: 1, stdout: "owner\n", stderr: "unexpected reply"),
        ] {
            let authority = await Self.authority(
                for: Self.workspace(repo), pullRequest: try await Self.pullRequest(in: repo), viewer: viewer
            )

            #expect(authority == .appOnly)
        }
    }

    @Test("a worktree on another branch or commit than the pull request's is doubt")
    func checkoutElsewhereIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        let workspace = Self.workspace(repo)
        let pullRequest = try await Self.pullRequest(in: repo)
        try await Shell.check("git", ["commit", "-q", "--allow-empty", "-m", "moved on"], cwd: repo.path)
        #expect(await Self.authority(for: workspace, pullRequest: pullRequest) == .appOnly)

        let onOther = try await Self.pullRequest(in: repo)
        try await Shell.check("git", ["checkout", "-q", "-b", "elsewhere"], cwd: repo.path)
        #expect(await Self.authority(for: workspace, pullRequest: onOther) == .appOnly)
    }

    @Test("a new branch in this repository may carry instructions once the read has answered")
    func unopenedBranchIsTrustedOnlyAfterARead() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        let workspace = Self.workspace(repo)
        let failure = GitHubReadFailure(reason: .rateLimited, message: "limited", retryAt: nil)

        #expect(await Self.authority(for: workspace) == .project)
        #expect(await Self.authority(for: workspace, wasRead: false) == .appOnly)
        #expect(await Self.authority(for: workspace, failure: failure) == .appOnly)
    }

    @Test("a worktree switched to another branch is doubt")
    func switchedBranchIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["checkout", "-q", "-b", "contrib"], cwd: repo.path)

        #expect(await Self.authority(for: Self.workspace(repo)) == .appOnly)
    }

    @Test("a worktree off its branch is doubt, whatever the recorded branch would say")
    func detachedHeadIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["checkout", "-q", "--detach"], cwd: repo.path)

        #expect(await Self.authority(for: Self.workspace(repo)) == .appOnly)
    }

    @Test("a recorded pull request number is doubt when the read found none")
    func recordedNumberIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }

        #expect(await Self.authority(for: Self.workspace(repo, recorded: 7)) == .appOnly)
    }

    @Test("a branch checked out from a pull request ref is doubt")
    func pullRequestRefIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["config", "branch.\(Self.branch).merge", "refs/pull/7/head"], cwd: repo.path)

        #expect(await Self.authority(for: Self.workspace(repo)) == .appOnly)
    }

    @Test("a branch that tracks a remote by address is doubt")
    func trackedAddressIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        try await Shell.check(
            "git", ["config", "branch.\(Self.branch).remote", "https://github.com/someone/app.git"], cwd: repo.path
        )

        #expect(await Self.authority(for: Self.workspace(repo)) == .appOnly)
    }

    @Test("a branch that pushes to another repository is doubt")
    func forkRemoteIsDoubt() async throws {
        let repo = try await Self.repoOnBranch()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["remote", "add", "fork", "https://github.com/someone/app"], cwd: repo.path)
        try await Shell.check("git", ["config", "branch.\(Self.branch).pushremote", "fork"], cwd: repo.path)

        #expect(await Self.authority(for: Self.workspace(repo)) == .appOnly)
    }
}
