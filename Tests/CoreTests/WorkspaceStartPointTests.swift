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

        let tag = try await WorkspaceManager.startPoint(of: "v1.0", in: repo.path)
        let commit = try await WorkspaceManager.startPoint(of: head, in: repo.path)
        let branch = try await WorkspaceManager.startPoint(of: "main", in: repo.path)
        let option = try await WorkspaceManager.startPoint(of: "-bad", in: repo.path)

        #expect(tag == "v1.0")
        #expect(commit == head)
        #expect(branch == head)
        #expect(option == "-bad")
    }

    @Test("a base whose first segment names a remote is still cut from the primary remote")
    func remoteNamedLikeABranchSegment() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let fork = try await TempRepo()
        defer { fork.cleanUp() }
        try await Shell.check("git", ["checkout", "-q", "-b", "new-ui"], cwd: fork.path)
        try fork.write("fork.md", "the fork's own work\n")
        try await fork.commit("fork work")

        try await Shell.check("git", ["checkout", "-q", "-b", "kid/new-ui"], cwd: server.path)
        try server.write("origin.md", "the branch the user picked\n")
        try await server.commit("origin work")
        let picked = try await Git.headSHA(of: server.path)

        let work = try await TempRepo.clone(of: server, named: "remote-named-clone")
        defer { work.cleanUp() }
        try await Shell.check("git", ["remote", "add", "kid", fork.path], cwd: work.path)
        try await Shell.check("git", ["fetch", "-q", "kid"], cwd: work.path)

        let manager = WorkspaceManager(store: try makeTestStore("remote-named-segment"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(
            repo: registered, prompt: "Pick the origin branch", baseBranch: "kid/new-ui"
        )

        #expect(try await Git.headSHA(of: workspace.path) == picked)
    }

    @Test("a base only the primary remote has is cut from it, whatever the checkout tracks")
    func primaryRemoteWinsOverWhatTheCheckoutTracks() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let elsewhere = try await TempRepo()
        defer { elsewhere.cleanUp() }

        try await Shell.check("git", ["checkout", "-q", "-b", "colleague/idea"], cwd: server.path)
        try server.write("idea.md", "only on origin\n")
        try await server.commit("an idea")
        let idea = try await Git.headSHA(of: server.path)

        let work = try await TempRepo.clone(of: server, named: "two-remote-clone")
        defer { work.cleanUp() }
        try await Shell.check("git", ["remote", "add", "fork", elsewhere.path], cwd: work.path)
        try await Shell.check("git", ["fetch", "-q", "fork"], cwd: work.path)
        try await Shell.check("git", ["config", "branch.main.remote", "fork"], cwd: work.path)

        let manager = WorkspaceManager(store: try makeTestStore("two-remote-cut"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(
            repo: registered, prompt: "Build on the idea", baseBranch: "colleague/idea"
        )

        #expect(try await Git.headSHA(of: workspace.path) == idea)
    }

    @Test("a base that exists nowhere says so in words the reader can act on")
    func missingBaseSaysWhy() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        await #expect(throws: ShellError.self) {
            _ = try await WorkspaceManager.startPoint(of: "never-existed", in: repo.path)
        }

        let raised: ShellError?
        do {
            _ = try await WorkspaceManager.startPoint(of: "never-existed", in: repo.path)
            raised = nil
        } catch let error as ShellError {
            raised = error
        }
        #expect(raised?.stderr.contains("could not find never-existed") == true)
    }

    @Test("with the remote unreachable the cut falls back to the last fetch, not to nothing")
    func unreachableRemoteUsesTheCachedRef() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "unreachable-clone")

        let cached = try await Git.headSHA(of: work.path)
        server.cleanUp()

        let manager = WorkspaceManager(store: try makeTestStore("unreachable-remote"))
        let registered = try await manager.addRepository(at: work.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Offline")
        defer { work.cleanUp() }

        #expect(try await Git.headSHA(of: workspace.path) == cached)
    }
}
