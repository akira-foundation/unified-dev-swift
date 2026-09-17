import Testing
import Foundation
@testable import Core

@Suite("Workspace ports", .scratchDirectory)
struct WorkspacePortTests {
    private func seed(
        _ store: Store, name: String = "w", port: Int = 0
    ) async throws -> (Repo, Workspace) {
        let repo = try await store.upsert(Repo(name: name, path: TestScratch.unique("repo")))
        var workspace = Workspace(
            repoID: repo.id, name: name, branch: "feature/\(name)",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        )
        workspace.port = port
        return (repo, try await store.upsert(workspace))
    }

    @Test("a workspace keeps its port across a restart")
    func aPortSurvivesARestart() async throws {
        let path = TestScratch.unique("port-restart") + ".sqlite"
        let store = try Store(path: path)
        let manager = WorkspaceManager(store: store)
        let (_, workspace) = try await seed(store)

        let allocated = await manager.ensurePort(for: workspace)
        #expect(allocated >= 3_100)

        let relaunched = try Store(path: path)
        let stored = try #require(try await relaunched.workspace(id: workspace.id))
        #expect(stored.port == allocated)
        #expect(await WorkspaceManager(store: relaunched).ensurePort(for: stored) == allocated)
    }

    @Test("allocation does not collide with a block another workspace already holds")
    func allocationAvoidsAStoredBlock() async throws {
        let store = try makeTestStore("port-collision")
        let manager = WorkspaceManager(store: store)
        let (_, held) = try await seed(store, name: "held", port: 3_100)
        let (_, asking) = try await seed(store, name: "asking")

        let allocated = await manager.ensurePort(for: asking)

        #expect(allocated != 0)
        let heldBlock = Set(held.port..<(held.port + PortAllocator.blockSize))
        let allocatedBlock = Set(allocated..<(allocated + PortAllocator.blockSize))
        #expect(heldBlock.isDisjoint(with: allocatedBlock))
    }

    @Test("two callers asking at once are given the same block")
    func concurrentCallersShareOneBlock() async throws {
        let store = try makeTestStore("port-race")
        let manager = WorkspaceManager(store: store)
        let (_, workspace) = try await seed(store)

        async let first = manager.ensurePort(for: workspace)
        async let second = manager.ensurePort(for: workspace)
        let (one, two) = await (first, second)

        #expect(one == two)
        #expect(try await store.workspace(id: workspace.id)?.port == one)
    }

    @Test("a row written before the column existed reads as holding no block, and can be given one")
    func anExistingDatabaseWithNoStoredPortStillAllocates() async throws {
        let path = TestScratch.unique("port-migration") + ".sqlite"
        let store = try Store(path: path)
        let (_, workspace) = try await seed(store, port: 4_200)

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        let stored = try #require(try await reopened.workspace(id: workspace.id))
        #expect(stored.port == 4_200)

        let (_, fresh) = try await seed(reopened, name: "fresh")
        #expect(fresh.port == 0)
        let allocated = await WorkspaceManager(store: reopened).ensurePort(for: fresh)
        #expect(allocated != 0)
        #expect(!(4_200..<4_210).contains(allocated))
    }

    @Test("an archived workspace does not hold its block")
    func archivedWorkspacesReleaseTheirBlock() async throws {
        let store = try makeTestStore("port-archived")
        let manager = WorkspaceManager(store: store)
        let (_, gone) = try await seed(store, name: "gone", port: 3_100)
        try await store.update(workspaceID: gone.id) { $0.archive() }

        #expect(await manager.takenPorts(excluding: WorkspaceID("nobody")).isEmpty)
    }

    @Test("the other writers of a workspace row leave the port alone")
    func writersKeepThePort() async throws {
        let store = try makeTestStore("port-isolation")
        let manager = WorkspaceManager(store: store)
        let (_, workspace) = try await seed(store)
        let allocated = await manager.ensurePort(for: workspace)

        try await store.updateDiffStat(workspaceID: workspace.id, additions: 4, deletions: 1, files: 2)
        try await store.touch(workspaceID: workspace.id, unread: true)
        try await store.update(workspaceID: workspace.id) { $0.pinned = true }

        #expect(try await store.workspace(id: workspace.id)?.port == allocated)
    }
}
