import Foundation
import Testing
@testable import Core

@Suite("A base branch named like a remote")
struct GitRepositoryContextBaseTests {
    private let remotes = [
        "remote.origin.url": "https://github.com/akira/app.git",
        "remote.kid.url": "https://github.com/kid/app.git",
    ]

    private func config(_ extra: [String: String]) -> [String: String] {
        remotes.merging(extra) { _, new in new }
    }

    @Test("a recorded base remote wins over a remote the name happens to start with")
    func recordedRemoteWins() {
        let context = GitRepositoryContext.resolve(
            config: config(["branch.feat.unifieddev-base-remote": "origin"]),
            base: "kid/new-ui",
            branch: "feat"
        )
        #expect(context.baseBranch == "kid/new-ui")
        #expect(context.baseRemote == "origin")
        #expect(context.baseTrackingRef == "refs/remotes/origin/kid/new-ui")
    }

    @Test("a name that starts with the recorded remote is that remote's branch")
    func recordedRemotePrefixIsSplit() {
        let context = GitRepositoryContext.resolve(
            config: config(["branch.feat.unifieddev-base-remote": "origin"]),
            base: "origin/main",
            branch: "feat"
        )
        #expect(context.baseBranch == "main")
        #expect(context.baseRemote == "origin")
    }

    @Test("a fully qualified remote ref is always split, whatever is recorded")
    func qualifiedRefIsSplit() {
        let context = GitRepositoryContext.resolve(
            config: config(["branch.feat.unifieddev-base-remote": "origin"]),
            base: "refs/remotes/kid/new-ui",
            branch: "feat"
        )
        #expect(context.baseBranch == "new-ui")
        #expect(context.baseRemote == "kid")
    }

    @Test("a name given as a branch is never split, however it starts")
    func branchNameIsNeverSplit() {
        let context = GitRepositoryContext.resolve(
            config: config(["branch.main.remote": "origin", "branch.main.merge": "refs/heads/main"]),
            base: "kid/new-ui",
            branch: "main",
            baseIsBranchName: true
        )
        #expect(context.baseBranch == "kid/new-ui")
        #expect(context.baseRemote == "origin")
    }

    @Test("with nothing recorded and nothing said, a remote prefix is still read as that remote")
    func unrecordedPrefixKeepsTodaysReading() {
        let context = GitRepositoryContext.resolve(config: config([:]), base: "kid/new-ui", branch: "feat")
        #expect(context.baseBranch == "new-ui")
        #expect(context.baseRemote == "kid")
    }
}

@Suite("Cutting from a branch named like a remote", .tags(.git, .destructive), .scratchDirectory)
struct RemoteNamedBaseCutTests {
    @Test("the cut records the whole name on the primary remote, and reads it back that way")
    func recordsTheWholeName() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        try await Shell.check("git", ["branch", "kid/new-ui"], cwd: server.path)
        let fork = try await TempRepo()
        defer { fork.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "remote-named-base")
        defer { work.cleanUp() }
        try await Shell.check("git", ["remote", "add", "kid", fork.path], cwd: work.path)

        let manager = WorkspaceManager(store: try makeTestStore("remote-named-base"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(
            repo: registered, prompt: "Carry the new UI on", baseBranch: "kid/new-ui"
        )

        let context = try await Git.repositoryContext(in: workspace.path)
        #expect(context.baseBranch == "kid/new-ui")
        #expect(context.baseRemote == "origin")
    }
}
