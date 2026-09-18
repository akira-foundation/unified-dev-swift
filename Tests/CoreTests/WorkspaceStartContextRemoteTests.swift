import Foundation
import Testing
@testable import Core

@Suite("Workspace start context against a real remote", .tags(.git), .scratchDirectory)
struct WorkspaceStartContextRemoteTests {
    @Test("a branch only the remote has is listed apart from the local ones")
    func loadListsRemoteOnlyBranches() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        try await Shell.check("git", ["branch", "colleague/idea"], cwd: server.path)
        let work = try await TempRepo.clone(of: server, named: "remote-listing")
        defer { work.cleanUp() }

        let context = await WorkspaceStartContext.load(repoPath: work.path)

        #expect(context.remoteBranches.contains("colleague/idea"))
        #expect(context.remoteBranches.contains("main"))
        #expect(!context.branches.contains("colleague/idea"))
    }

    @Test("the create window's prefetch brings the remote base up to date")
    func prefetchFetchesTheBase() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "prefetch-target")
        defer { work.cleanUp() }

        try server.write("landed.md", "merged since the clone\n")
        try await server.commit("land")
        let current = try await Git.headSHA(of: server.path)

        await WorkspaceStartContext.prefetch(BaseBranchPrefetch(repoPath: work.path, baseBranch: "main"))

        #expect(await Git.revision(of: "refs/remotes/origin/main", in: work.path) == current)
    }

    @Test("no target fetches nothing")
    func noTargetFetchesNothing() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "prefetch-nothing")
        defer { work.cleanUp() }
        let before = await Git.revision(of: "refs/remotes/origin/main", in: work.path)

        try server.write("landed.md", "merged since the clone\n")
        try await server.commit("land")
        await WorkspaceStartContext.prefetch(nil)

        #expect(await Git.revision(of: "refs/remotes/origin/main", in: work.path) == before)
    }

    @Test("a second prefetch inside the trust window does not go to the remote again")
    func prefetchTrustsTheRecentSuccess() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        let work = try await TempRepo.clone(of: server, named: "prefetch-twice")
        defer { work.cleanUp() }
        let target = BaseBranchPrefetch(repoPath: work.path, baseBranch: "main")

        await WorkspaceStartContext.prefetch(target)
        let afterFirst = await Git.revision(of: "refs/remotes/origin/main", in: work.path)

        try server.write("later.md", "landed after the first prefetch\n")
        try await server.commit("later")
        await WorkspaceStartContext.prefetch(target)

        #expect(afterFirst != nil)
        #expect(await Git.revision(of: "refs/remotes/origin/main", in: work.path) == afterFirst)
    }

    @Test("opening the sheet lists a branch published after the last fetch, and drops a deleted one")
    func branchListCatchesUpWithTheRemote() async throws {
        let server = try await TempRepo()
        defer { server.cleanUp() }
        try await Shell.check("git", ["branch", "gone/soon"], cwd: server.path)
        let work = try await TempRepo.clone(of: server, named: "list-catch-up")
        defer { work.cleanUp() }

        try await Shell.check("git", ["branch", "colleague/idea"], cwd: server.path)
        try await Shell.check("git", ["branch", "-D", "gone/soon"], cwd: server.path)
        let before = await WorkspaceStartContext.branchListing(repoPath: work.path)

        let fetched = await WorkspaceStartContext.fetchBranchList(repoPath: work.path)
        let after = await WorkspaceStartContext.branchListing(repoPath: work.path)

        #expect(!before.remote.contains("colleague/idea"))
        #expect(before.remote.contains("gone/soon"))
        #expect(fetched)
        #expect(Set(after.remote) == ["main", "colleague/idea"])
        #expect(after.local == ["main"])
    }

    @Test("a repository with no remote has no list to fetch")
    func noRemoteFetchesNoList() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }

        let fetched = await WorkspaceStartContext.fetchBranchList(repoPath: repo.path)

        #expect(!fetched)
    }
}
