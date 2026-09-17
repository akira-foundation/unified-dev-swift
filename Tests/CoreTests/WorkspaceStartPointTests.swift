import Foundation
import Testing
@testable import Core

@Suite("Start point of a new workspace", .tags(.git, .destructive), .scratchDirectory)
struct WorkspaceStartPointTests {
    @Test("a new workspace starts from the base as the remote has it, not the stale local copy")
    func startsFromTheRemote() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "stale-clone")
        defer { work.cleanUp() }

        let stale = try await Git.headSHA(of: work.path)
        try server.write("landed.md", "merged while the clone sat still\n")
        try await server.commit("land something")
        let current = try await Git.headSHA(of: server.path)

        let manager = WorkspaceManager(store: try makeTestStore("start-from-remote"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Next thing")

        #expect(try await Git.headSHA(of: workspace.path) == current)
        #expect(workspace.baseBranch == registered.defaultBranch)
        #expect(await Git.revision(of: "refs/heads/\(registered.defaultBranch)", in: work.path) == stale)
    }

    @Test("a branch only the remote has is a base a workspace can start from")
    func startsFromARemoteOnlyBranch() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "remote-only-base")
        defer { work.cleanUp() }

        try await Shell.check("git", ["checkout", "-q", "-b", "colleague/idea"], cwd: server.path)
        try server.write("idea.md", "pushed after the clone was made\n")
        try await server.commit("an idea")
        let idea = try await Git.headSHA(of: server.path)

        let manager = WorkspaceManager(store: try makeTestStore("start-from-remote-only"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(
            repo: registered, prompt: "Build on the idea", baseBranch: "colleague/idea"
        )

        #expect(try await Git.headSHA(of: workspace.path) == idea)
        #expect(workspace.baseBranch == "colleague/idea")
    }

    @Test("a fetch made while the task was being written is the one the cut starts from")
    func cutTrustsARecentPrefetch() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "prefetched-clone")
        defer { work.cleanUp() }

        let manager = WorkspaceManager(store: try makeTestStore("start-from-prefetch"))
        let registered = try await manager.addRepository(at: work.path)

        try server.write("first.md", "fetched ahead of Create\n")
        try await server.commit("first")
        let prefetched = try await Git.headSHA(of: server.path)
        await BaseBranchFetches.prefetch(base: registered.defaultBranch, in: registered.path)

        try server.write("second.md", "landed after the prefetch\n")
        try await server.commit("second")

        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Trust the prefetch")

        #expect(try await Git.headSHA(of: workspace.path) == prefetched)
    }

    @Test("continuing after a merge fetches again, however recent the last fetch was")
    func continuationNeverTrustsAnEarlierFetch() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "continued-clone")
        defer { work.cleanUp() }

        await BaseBranchFetches.prefetch(base: "main", in: work.path)
        try server.write("merged.md", "the pull request that was just merged\n")
        try await server.commit("merge")
        let merged = try await Git.headSHA(of: server.path)

        let resolved = try await Git.baseRevision(branch: "main", in: work.path)

        #expect(resolved.revision == merged)
        #expect(resolved.base == .fetched)
    }

    @Test("a repository with no remote still starts from its local branch")
    func noRemoteUsesTheLocalBranch() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let head = try await Git.headSHA(of: repo.path)

        let manager = WorkspaceManager(store: try makeTestStore("start-without-remote"))
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Local only")

        #expect(try await Git.headSHA(of: workspace.path) == head)
    }

    @Test("a tag or a commit is passed through for git to resolve on its own")
    func nonBranchBasesPassThrough() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try await Shell.check("git", ["tag", "v1.0"], cwd: repo.path)
        let head = try await Git.headSHA(of: repo.path)

        #expect(await WorkspaceManager.startPoint(of: "v1.0", in: repo.path) == "v1.0")
        #expect(await WorkspaceManager.startPoint(of: head, in: repo.path) == head)
        #expect(await WorkspaceManager.startPoint(of: "main", in: repo.path) == head)
        #expect(await WorkspaceManager.startPoint(of: "-bad", in: repo.path) == "-bad")
    }
}
