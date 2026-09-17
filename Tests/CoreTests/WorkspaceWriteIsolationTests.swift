import Testing
import Foundation
@testable import Core

@Suite("Workspace write isolation", .tags(.persistence), .scratchDirectory)
struct WorkspaceWriteIsolationTests {
    private func seed(_ store: Store) async throws -> Workspace {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        return try await store.upsert(Workspace(
            repoID: repo.id, name: "original", branch: "feature/original",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
    }

    @Test("a write leaves alone every column it did not name")
    func writeTouchesOnlyWhatItNames() async throws {
        let store = try makeTestStore("isolation")
        let workspace = try await seed(store)

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 12, deletions: 3, files: 2)
        try await store.touch(workspaceID: workspace.id, unread: true)
        try await store.update(workspaceID: workspace.id) {
            $0.apply(.runStarted)
            $0.apply(.runFinished(succeeded: true, log: "done"))
        }

        try await store.update(workspaceID: workspace.id) { $0.pinned = true }

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.pinned)
        #expect(stored.additions == 12)
        #expect(stored.deletions == 3)
        #expect(stored.changedFiles == 2)
        #expect(stored.unread)
        #expect(stored.setupState == .succeeded)
        #expect(stored.setupLog == "done")
        #expect(stored.lastActivityAt > workspace.lastActivityAt)
    }

    @Test("pinning a workspace cannot bring it back from archived")
    func pinCannotUnarchive() async throws {
        let store = try makeTestStore("isolation")
        let workspace = try await seed(store)

        try await store.update(workspaceID: workspace.id) {
            $0.archive()
            $0.archivedAt = Date()
        }
        try await store.update(workspaceID: workspace.id) { $0.pinned.toggle() }

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.state == .archived)
        #expect(stored.archivedAt != nil)
        #expect(stored.pinned)
        #expect(try await store.workspaces().isEmpty)
    }

    @Test("a toggle is against the stored value, not against the caller's copy")
    func toggleIsAgainstTheStoredValue() async throws {
        let store = try makeTestStore("isolation")
        let workspace = try await seed(store)

        try await store.update(workspaceID: workspace.id) { $0.pinned.toggle() }
        try await store.update(workspaceID: workspace.id) { $0.pinned.toggle() }

        #expect(try await store.workspace(id: workspace.id)?.pinned == false)
    }

    @Test("a targeted write does not recreate a workspace that is gone")
    func doesNotRecreateADeletedWorkspace() async throws {
        let store = try makeTestStore("isolation")
        let workspace = try await seed(store)
        try await store.deleteWorkspace(id: workspace.id)

        let result = try await store.update(workspaceID: workspace.id) { $0.name = "back from the dead" }

        #expect(result == nil)
        #expect(try await store.workspaces(includeArchived: true).isEmpty)
    }

    @Test("a write cannot change which workspace it is or which project it belongs to")
    func cannotChangeIdentity() async throws {
        let store = try makeTestStore("isolation")
        let workspace = try await seed(store)
        let other = try await store.upsert(Repo(name: "other", path: TestScratch.unique("other")))

        try await store.update(workspaceID: workspace.id) {
            $0.id = WorkspaceID("some-other-id")
            $0.repoID = other.id
            $0.name = "renamed"
        }

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.id == workspace.id)
        #expect(stored.repoID == workspace.repoID)
        #expect(stored.name == "renamed")
        #expect(try await store.workspaces(repoID: other.id).isEmpty)
    }

    @Test("marking a workspace unread, and colouring it, touch nothing else")
    func theHandMarksTouchNothingElse() async throws {
        let store = try makeTestStore("marks")
        let workspace = try await seed(store)

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 4, deletions: 1, files: 1)
        try await store.update(workspaceID: workspace.id) { $0.pinned = true }

        try await store.update(workspaceID: workspace.id) { $0.unread = true }
        try await store.update(workspaceID: workspace.id) { $0.colour = "22A06B" }

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.unread)
        #expect(stored.colour == "22A06B")
        #expect(stored.pinned)
        #expect(stored.additions == 4)
        #expect(stored.name == "original")

        try await store.update(workspaceID: workspace.id) { $0.colour = nil }
        let cleared = try #require(try await store.workspace(id: workspace.id))
        #expect(cleared.colour == nil)
        #expect(cleared.unread)
        #expect(cleared.pinned)
    }

    @Test("the colour migration survives being replayed, and keeps what was stored")
    func theColourMigrationReplays() async throws {
        let path = TestScratch.unique("colour-replay") + ".sqlite"
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("worktree"),
            baseBranch: "main"
        ))
        try await store.update(workspaceID: workspace.id) { $0.colour = "D8608C" }

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        let stored = try #require(try await reopened.workspace(id: workspace.id))
        #expect(stored.colour == "D8608C")
    }

    @Test("the writers of a workspace row leave its parentage alone")
    func writersKeepTheOrigin() async throws {
        let store = try makeTestStore("isolation")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let parent = try await seed(store)
        let started = try await store.upsert(Workspace(
            repoID: repo.id, name: "started", branch: "feature/started",
            path: TestScratch.unique("worktree"),
            baseBranch: "main",
            origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_01")
        ))

        try await store.updateDiffStat(workspaceID: started.id, additions: 9, deletions: 1, files: 1)
        try await store.touch(workspaceID: started.id, unread: true)
        try await store.update(workspaceID: started.id) {
            $0.apply(.runStarted)
            $0.apply(.runFinished(succeeded: true, log: "done"))
        }
        try await store.update(workspaceID: started.id) { $0.name = "named by the model" }
        try await store.update(workspaceID: started.id) {
            $0.archive()
            $0.archivedAt = Date()
        }

        let stored = try #require(try await store.workspace(id: started.id))
        #expect(stored.origin == .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_01"))
        #expect(stored.name == "named by the model")
        #expect(stored.state == .archived)
    }

    @Test("a workspace the owner made never acquires a parent")
    func theOwnersWorkspacesStayTheOwners() async throws {
        let store = try makeTestStore("isolation")
        let workspace = try await seed(store)
        #expect(workspace.origin == .user)

        try await store.update(workspaceID: workspace.id) { $0.pinned = true }
        try await store.touch(workspaceID: workspace.id, unread: true)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.origin == .user)
        #expect(stored.origin.isAgentSpawned == false)
    }

    @Test("the parentage migration survives being replayed, and keeps what was stored")
    func theParentageMigrationReplays() async throws {
        let path = TestScratch.unique("parentage-replay") + ".sqlite"
        let store = try Store(path: path)
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let parent = try await store.upsert(Workspace(
            repoID: repo.id, name: "parent", branch: "b", path: TestScratch.unique("worktree"),
            baseBranch: "main"
        ))
        let started = try await store.upsert(Workspace(
            repoID: repo.id, name: "started", branch: "b2", path: TestScratch.unique("worktree"),
            baseBranch: "main",
            origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_02")
        ))

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        let storedParent = try #require(try await reopened.workspace(id: parent.id))
        let storedChild = try #require(try await reopened.workspace(id: started.id))
        #expect(storedParent.origin == .user)
        #expect(storedChild.origin == .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_02"))
    }
}

@Suite("Workspaces an agent started", .tags(.persistence), .scratchDirectory)
struct WorkspaceParentageTests {
    private func seed(_ store: Store) async throws -> Repo {
        try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
    }

    private func makeWorkspace(
        _ store: Store, repo: Repo, name: String, origin: WorkspaceOrigin = .user
    ) async throws -> Workspace {
        try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: "feature/\(name)",
            path: TestScratch.unique("worktree"), baseBranch: "main", origin: origin
        ))
    }

    @Test("the list of what an agent started leaves out what it archived")
    func listsTheLiveOnes() async throws {
        let store = try makeTestStore("parentage")
        let repo = try await seed(store)
        let parent = try await makeWorkspace(store, repo: repo, name: "parent")
        let first = try await makeWorkspace(
            store, repo: repo, name: "first",
            origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_a")
        )
        let second = try await makeWorkspace(
            store, repo: repo, name: "second",
            origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_b")
        )
        _ = try await makeWorkspace(store, repo: repo, name: "unrelated")

        try await store.update(workspaceID: second.id) { $0.archive() }

        let live = try await store.workspaces(startedBy: parent.id)
        #expect(live.map(\.id) == [first.id])

        let all = try await store.workspaces(startedBy: parent.id, includeArchived: true)
        #expect(Set(all.map(\.id)) == [first.id, second.id])
    }

    @Test("archiving does not refund an agent its budget")
    func archivingDoesNotRefundTheBudget() async throws {
        let store = try makeTestStore("parentage")
        let repo = try await seed(store)
        let parent = try await makeWorkspace(store, repo: repo, name: "parent")

        for index in 0..<3 {
            let started = try await makeWorkspace(
                store, repo: repo, name: "started\(index)",
                origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_\(index)")
            )
            try await store.update(workspaceID: started.id) {
                $0.archive()
                $0.archivedAt = Date()
            }
        }

        #expect(try await store.workspaces(startedBy: parent.id).isEmpty)
        #expect(try await store.countWorkspaces(startedBy: parent.id) == 3)
    }

    @Test("a workspace keeps its parentage after the parent is gone")
    func parentageOutlivesTheParent() async throws {
        let store = try makeTestStore("parentage")
        let repo = try await seed(store)
        let parent = try await makeWorkspace(store, repo: repo, name: "parent")
        let started = try await makeWorkspace(
            store, repo: repo, name: "started",
            origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_c")
        )

        try await store.deleteWorkspace(id: parent.id)

        let stored = try #require(try await store.workspace(id: started.id))
        #expect(stored.origin == .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_c"))
        #expect(try await store.workspace(id: parent.id) == nil)
    }

    @Test("a tool call can find what it already made")
    func aToolCallFindsWhatItMade() async throws {
        let store = try makeTestStore("parentage")
        let repo = try await seed(store)
        let parent = try await makeWorkspace(store, repo: repo, name: "parent")
        let started = try await makeWorkspace(
            store, repo: repo, name: "started",
            origin: .agent(parentWorkspaceID: parent.id, spawnToolUseID: "toolu_d")
        )
        try await store.update(workspaceID: started.id) { $0.archive() }

        #expect(try await store.workspaces(spawnToolUseID: "toolu_d").map(\.id) == [started.id])
        #expect(try await store.workspaces(spawnToolUseID: "toolu_none").isEmpty)
    }

    @Test("a parent id with no tool call beside it grants nothing")
    func halfARecordGrantsNothing() async throws {
        #expect(WorkspaceOrigin(parentWorkspaceID: "w1", spawnToolUseID: nil) == .user)
        #expect(
            WorkspaceOrigin(parentWorkspaceID: "w1", spawnToolUseID: "toolu_e")
                == .agent(parentWorkspaceID: WorkspaceID("w1"), spawnToolUseID: "toolu_e")
        )
    }

    @Test("a tool call with no parent is the owner's own client, and still not an agent's")
    func aToolCallWithNoParentIsTheOwners() async throws {
        #expect(
            WorkspaceOrigin(parentWorkspaceID: nil, spawnToolUseID: "toolu_e")
                == .ownerClient(spawnToolUseID: "toolu_e")
        )
        #expect(
            WorkspaceOrigin(parentWorkspaceID: "", spawnToolUseID: "toolu_e")
                == .ownerClient(spawnToolUseID: "toolu_e")
        )
        #expect(WorkspaceOrigin.ownerClient(spawnToolUseID: "toolu_e").isAgentSpawned == false)
        #expect(BridgeRole(origin: .ownerClient(spawnToolUseID: "toolu_e")) == .parent)
    }
}

@Suite("Workspace write isolation through git", .tags(.git, .destructive), .scratchDirectory)
struct WorkspaceWriteIsolationGitTests {
    private func makeWorkspace() async throws
    -> (repo: TempRepo, registered: Repo, manager: WorkspaceManager, store: Store, workspace: Workspace) {
        let repo = try await TempRepo()
        let store = try makeTestStore("isolation-git")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Write isolation")
        return (repo, registered, manager, store, workspace)
    }

    @Test("an archive does not undo a rename that landed while it ran")
    func archiveKeepsAConcurrentRename() async throws {
        let (repo, registered, manager, store, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await store.update(workspaceID: workspace.id) { $0.name = "named by the model" }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.name == "named by the model")
        #expect(stored.state == .archived)
    }

    @Test("an archive does not undo the diff stats and the unread mark")
    func archiveKeepsConcurrentActivity() async throws {
        let (repo, registered, manager, store, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 40, deletions: 1, files: 3)
        try await store.touch(workspaceID: workspace.id, unread: true)

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.additions == 40)
        #expect(stored.unread)
        #expect(stored.state == .archived)
    }

    @Test("a workspace archived while its row moved on is still archived after a relaunch")
    func archiveSurvivesARelaunch() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let path = TestScratch.unique("relaunch") + ".sqlite"
        let store = try Store(path: path)
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Relaunch")

        try await store.update(workspaceID: workspace.id) { $0.pinned = true }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)

        let relaunched = try Store(path: path)
        let stored = try #require(try await relaunched.workspace(id: workspace.id))
        #expect(stored.state == .archived)
        #expect(stored.archivedAt != nil)
        #expect(try await relaunched.workspaces().isEmpty)
        #expect(FileManager.default.fileExists(atPath: stored.path) == false)
    }

    @Test("continuing on a new branch does not undo a rename that landed while it ran")
    func continuationKeepsAConcurrentRename() async throws {
        let (repo, _, manager, store, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await store.update(workspaceID: workspace.id) { $0.name = "named by the model" }

        let continuation = try await manager.continueOnNewBranch(
            workspace: workspace, branch: "feature/next"
        )

        #expect(continuation.branch == "feature/next")
        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.name == "named by the model")
        #expect(stored.branch == "feature/next")
    }

    @Test("a restore does not undo a turn that finished while the worktree was rebuilt")
    func restoreKeepsConcurrentActivity() async throws {
        let (repo, registered, manager, store, workspace) = try await makeWorkspace()
        defer { repo.cleanUp() }

        try await manager.archive(workspace: workspace, repo: registered, deleteBranch: false)
        let archived = try #require(try await store.workspace(id: workspace.id))

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 7, deletions: 2, files: 1)
        try await store.touch(workspaceID: workspace.id, unread: true)

        try await manager.restore(workspace: archived, repo: registered)

        let stored = try #require(try await store.workspace(id: workspace.id))
        #expect(stored.state == .active)
        #expect(stored.archivedAt == nil)
        #expect(stored.additions == 7)
        #expect(stored.unread)
    }
}
