import Testing
import Foundation
@testable import Core

@Suite("Profile scope", .tags(.persistence), .scratchDirectory)
struct ProfileScopeTests {
    private func workspace(_ name: String, repo: Repo, parent: Workspace? = nil) -> Workspace {
        var row = Workspace(repoID: repo.id, name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main")
        if let parent { row.origin = .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_1") }
        return row
    }

    @Test("workspaces follow the profile of their project")
    func workspacesFollowProfile() {
        let akira = ProfileID("akira")
        let inUnified = Repo(name: "a", path: "/tmp/a")
        let inAkira = Repo(name: "b", path: "/tmp/b", profileID: akira)
        let unifiedRoot = workspace("u1", repo: inUnified)
        let unifiedChild = workspace("u2", repo: inUnified, parent: unifiedRoot)
        let akiraRoot = workspace("k1", repo: inAkira)
        let akiraChild = workspace("k2", repo: inAkira, parent: akiraRoot)
        let orphan = workspace("o1", repo: Repo(name: "c", path: "/tmp/c"))
        let all = [unifiedRoot, unifiedChild, akiraRoot, akiraChild, orphan]
        let repos = [inUnified, inAkira]

        #expect(ProfileScope.repos(repos, in: akira).map(\.id) == [inAkira.id])
        #expect(ProfileScope.workspaces(all, repos: repos, in: akira).map(\.id) == [akiraRoot.id, akiraChild.id])
        #expect(ProfileScope.workspaces(all, repos: repos, in: .initial).map(\.id) == [unifiedRoot.id, unifiedChild.id])
        #expect(ProfileScope.profile(of: akiraChild.id, workspaces: all, repos: repos) == akira)
        #expect(ProfileScope.profile(of: orphan.id, workspaces: all, repos: repos) == nil)
        #expect(ProfileScope.profile(of: .new(), workspaces: all, repos: repos) == nil)
    }

    @Test("transcript matches keep only workspaces of the profile, archived ones included")
    func transcriptsFollowProfile() {
        let akira = ProfileID("akira")
        let inUnified = Repo(name: "a", path: "/tmp/a")
        let inAkira = Repo(name: "b", path: "/tmp/b", profileID: akira)
        let mine = workspace("m", repo: inUnified)
        let theirs = workspace("t", repo: inAkira)
        let unknown = WorkspaceID.new()
        let matches = [mine.id, theirs.id, unknown].map {
            TranscriptWorkspaceMatches(workspaceID: $0, matches: [], total: 1)
        }
        let owners = [mine.id: inUnified.id, theirs.id: inAkira.id]

        let shownInAkira = ProfileScope.transcripts(matches, owners: owners, repos: [inUnified, inAkira], in: akira)
        let shownInUnified = ProfileScope.transcripts(matches, owners: owners, repos: [inUnified, inAkira], in: .initial)

        #expect(shownInAkira.map(\.workspaceID) == [theirs.id])
        #expect(shownInUnified.map(\.workspaceID) == [mine.id])
    }

    @Test("landing falls back to home when the remembered workspace is gone")
    func landingFallsBack() {
        let akira = ProfileID("akira")
        let remembered = WorkspaceID.new()
        var memory = ProfileMemory()
        #expect(memory.landing(for: akira, live: [remembered]) == .home)
        memory.remember(remembered, in: akira)
        #expect(memory.landing(for: akira, live: [remembered]) == .workspace(remembered))
        #expect(memory.landing(for: akira, live: []) == .home)
        #expect(memory.landing(for: .initial, live: [remembered]) == .home)
    }

    @Test("memory survives a JSON round trip")
    func memoryRoundTrip() throws {
        var memory = ProfileMemory()
        let workspace = WorkspaceID.new()
        memory.remember(workspace, in: ProfileID("akira"))
        memory.remember(.new(), in: .initial)
        let decoded = try JSONDecoder().decode(ProfileMemory.self, from: JSONEncoder().encode(memory))
        #expect(decoded == memory)
        #expect(decoded.landing(for: ProfileID("akira"), live: [workspace]) == .workspace(workspace))
    }

    @Test("moving a project keeps its workspaces, paths and sessions, and an account its new profile also holds")
    func moveKeepsWorkspaces() async throws {
        let store = try makeTestStore("profile-scope-move")
        let akira = try await store.createProfile(
            name: "Akira", colour: Accent.all[2], symbol: "a.circle", accounts: .inherits
        )
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let first = try await store.upsert(workspace("w1", repo: repo))
        let second = try await store.upsert(workspace("w2", repo: repo))
        _ = try await store.upsert(Session(workspaceID: first.id, title: "Chat"))
        let account = try #require(AgentAccountHome.defaultHome(for: .claudeCode, home: URL(filePath: "/Users/someone")))
        try await AgentAccountAssignment.choose(ChosenAgentAccount(account), forRepo: repo.id, in: store)
        let before = try await store.workspaces(repoID: repo.id, includeArchived: true)
        let sessionsBefore = try await store.sessions(workspaceID: first.id)
        let choicesBefore = try await store.agentAccountChoices()

        let moved = try await store.move(repoID: repo.id, to: akira.id)

        #expect(moved?.profileID == akira.id)
        #expect(try await store.repo(id: repo.id)?.profileID == akira.id)
        #expect(try await store.workspaces(repoID: repo.id, includeArchived: true) == before)
        #expect(Set(before.map(\.id)) == [first.id, second.id])
        #expect(sessionsBefore.count == 1)
        #expect(try await store.sessions(workspaceID: first.id) == sessionsBefore)
        #expect(choicesBefore.repos[repo.id] == [.claudeCode: account.id])
        #expect(try await store.agentAccountChoices().repos == choicesBefore.repos)
    }

    @Test("moving to a missing profile is refused")
    func moveRefused() async throws {
        let store = try makeTestStore("profile-scope-refused")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        await #expect(throws: ProfileMoveRefused.unknownProfile) {
            try await store.move(repoID: repo.id, to: ProfileID("ghost"))
        }
        #expect(try await store.repo(id: repo.id)?.profileID == .initial)
    }

    @Test("moving an unknown project answers nil")
    func moveUnknownRepo() async throws {
        let store = try makeTestStore("profile-scope-unknown")
        let moved = try await store.move(repoID: .new(), to: .initial)
        #expect(moved == nil)
    }

    @Test("a project asked for by name is the active profile's before another profile's")
    func repoByNamePrefersActiveProfile() {
        let elsewhere = Repo(name: "api", path: "/a/api", profileID: ProfileID("akira"))
        let here = Repo(name: "api", path: "/d/api", profileID: ProfileID("debtges"))
        let repos = [elsewhere, here]
        #expect(ProfileScope.repo(named: "api", in: repos, preferring: ProfileID("debtges"))?.id == here.id)
        #expect(ProfileScope.repo(named: "api", in: repos, preferring: .initial)?.id == elsewhere.id)
        #expect(ProfileScope.repo(named: "web", in: repos, preferring: ProfileID("debtges")) == nil)
        #expect(ProfileScope.repo(named: nil, in: repos, preferring: ProfileID("debtges")) == nil)
    }

    @Test("digits pick profiles in order")
    func digitsPickProfiles() {
        let profiles = ["a", "b", "c"].map {
            Profile(id: ProfileID($0), name: $0, folder: $0, colour: Accent.all[0], symbol: "circle", sortOrder: 0)
        }
        #expect(ProfileShortcut.profile(at: 1, among: profiles) == ProfileID("a"))
        #expect(ProfileShortcut.profile(at: 2, among: profiles) == ProfileID("b"))
        #expect(ProfileShortcut.profile(at: 3, among: profiles) == ProfileID("c"))
        #expect(ProfileShortcut.profile(at: 4, among: profiles) == nil)
        #expect(ProfileShortcut.profile(at: 0, among: profiles) == nil)
        #expect(ProfileShortcut.profile(at: 10, among: profiles) == nil)
    }
}
