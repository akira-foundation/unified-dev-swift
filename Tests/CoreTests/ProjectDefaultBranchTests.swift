import Foundation
import Testing
@testable import Core

@Suite("Project default branch", .tags(.git))
struct ProjectDefaultBranchTests {
    private func cloneWhoseRemoteMovedTo(_ branch: String) async throws -> (server: TempRepo, clone: TempRepo) {
        let server = try await TempRepo(defaultBranch: "main")
        let clone = try await TempRepo.clone(of: server, named: "unifieddev-default-clone")
        try await Shell.check("git", ["branch", branch], cwd: server.path)
        try await Shell.check("git", ["symbolic-ref", "HEAD", "refs/heads/\(branch)"], cwd: server.path)
        try await Shell.check("git", ["fetch", "-q", "origin"], cwd: clone.path)
        return (server, clone)
    }

    @Test("reads the branch the remote's HEAD names")
    func parsesListing() {
        let listing = "ref: refs/heads/develop\tHEAD\nbcbf627af85c8d520976c254c9ea942781fb1ec1\tHEAD\n"
        #expect(Git.remoteHeadBranch(inListing: listing) == "develop")
    }

    @Test("a listing with no symbolic HEAD names no branch")
    func detachedListing() {
        #expect(Git.remoteHeadBranch(inListing: "bcbf627af85c8d520976c254c9ea942781fb1ec1\tHEAD\n") == nil)
        #expect(Git.remoteHeadBranch(inListing: "ref: refs/heads/main\trefs/heads/other\n") == nil)
        #expect(Git.remoteHeadBranch(inListing: "") == nil)
    }

    @Test("a remote announcing a name git would refuse names no branch")
    func refusesInvalidName() {
        #expect(Git.remoteHeadBranch(inListing: "ref: refs/heads/-x\tHEAD\n") == nil)
        #expect(Git.remoteHeadBranch(inListing: "ref: refs/heads/a..b\tHEAD\n") == nil)
    }

    @Test("a single branch clone that never fetched the announced branch keeps its local answer")
    func announcedBranchMissingLocally() async throws {
        let server = try await TempRepo(defaultBranch: "main")
        defer { server.cleanUp() }
        try await Shell.check("git", ["branch", "feature"], cwd: server.path)
        let path = TestScratch.unique("unifieddev-single-branch")
        try await Shell.check("git", ["clone", "-q", "--single-branch", "-b", "feature", server.path, path])
        let clone = TempRepo(existing: path)
        defer { clone.cleanUp() }

        #expect(await Git.remoteDefaultBranch(of: clone.path) == nil)
        #expect(try await Git.defaultBranch(of: clone.path) == "feature")
    }

    @Test("the remote asked is the one the current branch takes its base from, not origin")
    func asksTheBaseRemote() async throws {
        let origin = try await TempRepo(defaultBranch: "main")
        let clone = try await TempRepo.clone(of: origin, named: "unifieddev-fork-clone")
        let upstream = try await TempRepo(defaultBranch: "main")
        defer { origin.cleanUp(); clone.cleanUp(); upstream.cleanUp() }
        try await Shell.check("git", ["branch", "develop"], cwd: upstream.path)
        try await Shell.check("git", ["symbolic-ref", "HEAD", "refs/heads/develop"], cwd: upstream.path)
        try await Shell.check("git", ["remote", "add", "upstream", upstream.path], cwd: clone.path)
        try await Shell.check("git", ["fetch", "-q", "upstream"], cwd: clone.path)
        try await Shell.check("git", ["config", "branch.main.remote", "upstream"], cwd: clone.path)

        #expect(await Git.remoteDefaultBranch(of: clone.path) == "develop")
    }

    @Test("the remote's HEAD wins over the clone's stale origin/HEAD, which is left alone")
    func remoteWinsOverStaleLocal() async throws {
        let (server, clone) = try await cloneWhoseRemoteMovedTo("develop")
        defer { server.cleanUp(); clone.cleanUp() }

        let local = try await Shell.check("git", ["symbolic-ref", "refs/remotes/origin/HEAD"], cwd: clone.path)
        #expect(local.trimmed == "refs/remotes/origin/main")
        #expect(await Git.remoteDefaultBranch(of: clone.path) == "develop")
        #expect(try await Git.defaultBranch(of: clone.path) == "develop")
        let after = try await Shell.check("git", ["symbolic-ref", "refs/remotes/origin/HEAD"], cwd: clone.path)
        #expect(after.trimmed == "refs/remotes/origin/main")
    }

    @Test("an unreachable remote falls back to the local answer")
    func unreachableRemoteFallsBack() async throws {
        let (server, clone) = try await cloneWhoseRemoteMovedTo("develop")
        defer { clone.cleanUp() }
        server.cleanUp()

        #expect(await Git.remoteDefaultBranch(of: clone.path) == nil)
        #expect(try await Git.defaultBranch(of: clone.path) == "main")
    }

    @Test("a stored default that the remote contradicts is corrected in the store")
    func refreshPersists() async throws {
        let (server, clone) = try await cloneWhoseRemoteMovedTo("develop")
        defer { server.cleanUp(); clone.cleanUp() }
        let store = try makeTestStore("default-branch")
        let repo = try await store.upsert(Repo(name: "project", path: clone.path, defaultBranch: "main"))

        let refreshed = await ProjectDefaultBranch.refresh(repo, in: store)

        #expect(refreshed.defaultBranch == "develop")
        #expect(try await store.repo(id: repo.id)?.defaultBranch == "develop")
    }

    @Test("an unreachable remote leaves the stored default as it was")
    func unreachableRemoteKeepsStored() async throws {
        let (server, clone) = try await cloneWhoseRemoteMovedTo("develop")
        defer { clone.cleanUp() }
        server.cleanUp()
        let store = try makeTestStore("default-branch-offline")
        let repo = try await store.upsert(Repo(name: "project", path: clone.path, defaultBranch: "develop"))

        let refreshed = await ProjectDefaultBranch.refresh(repo, in: store)

        #expect(refreshed.defaultBranch == "develop")
        #expect(try await store.repo(id: repo.id)?.defaultBranch == "develop")
    }

    @Test("a row whose default changed since it was read is not overwritten")
    func concurrentChangeWins() async throws {
        let store = try makeTestStore("default-branch-race")
        let read = try await store.upsert(Repo(name: "project", path: "/nowhere", defaultBranch: "main"))
        _ = try await store.update(repoID: read.id) { $0.defaultBranch = "trunk" }

        let adopted = await ProjectDefaultBranch.adopt("develop", for: read, in: store)

        #expect(adopted.defaultBranch == "trunk")
        #expect(try await store.repo(id: read.id)?.defaultBranch == "trunk")
    }

    @Test("a draft still on the old default follows the new one, any other choice stays")
    func retargetsUntouchedDraft() {
        let moved = ProjectDefaultBranch.startingPoint(.newBranch(from: "main"), after: "main", became: "develop")
        let chosen = ProjectDefaultBranch.startingPoint(.newBranch(from: "feature"), after: "main", became: "develop")
        let existing = WorkspaceStartingPoint.existingBranch(ExistingBranch(name: "main", isLocal: true))
        let kept = ProjectDefaultBranch.startingPoint(existing, after: "main", became: "develop")

        #expect(moved == .newBranch(from: "develop"))
        #expect(chosen == .newBranch(from: "feature"))
        #expect(kept == existing)
    }
}
