import Foundation
import Testing
@testable import Core

@Suite("Store orchestrator", .tags(.persistence), .scratchDirectory)
struct StoreOrchestratorTests {
    private func seed(_ store: Store, names: [String] = ["lead", "other"]) async throws -> [Workspace] {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        var rows: [Workspace] = []
        for name in names {
            rows.append(try await store.upsert(Workspace(
                repoID: repo.id, name: name, branch: "b/\(name)",
                path: TestScratch.unique(name), baseBranch: "main"
            )))
        }
        return rows
    }

    @Test("marking a workspace the orchestrator stores the flag and pins it")
    func markStoresAndPins() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)

        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        let stored = try #require(try await store.workspace(id: rows[0].id))
        #expect(stored.isOrchestrator)
        #expect(stored.pinned)
    }

    @Test("a second orchestrator in the project is refused and the first keeps the flag")
    func secondIsRefused() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        await #expect(throws: WorkspaceError.self) {
            try await store.setOrchestrator(true, workspaceID: rows[1].id)
        }

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == true)
        #expect(try await store.workspace(id: rows[1].id)?.isOrchestrator == false)
    }

    @Test("the database itself refuses a second orchestrator in one project")
    func indexRefusesSecond() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        var second = rows[1]
        second.isOrchestrator = true
        await #expect(throws: (any Error).self) { try await store.upsert(second) }
    }

    @Test("two projects may each have their own orchestrator")
    func oneEachIsFine() async throws {
        let store = try makeTestStore("orchestrator")
        let first = try await seed(store, names: ["a"])
        let second = try await seed(store, names: ["b"])

        try await store.setOrchestrator(true, workspaceID: first[0].id)
        try await store.setOrchestrator(true, workspaceID: second[0].id)

        #expect(try await store.workspace(id: second[0].id)?.isOrchestrator == true)
    }

    @Test("unpinning an orchestrator leaves it pinned, by edit and by drag")
    func staysPinned() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        try await store.update(workspaceID: rows[0].id) { $0.pinned = false }
        #expect(try await store.workspace(id: rows[0].id)?.pinned == true)

        try await store.reorderWorkspaces([SidebarReorder.Change(id: rows[0].id, sortOrder: 4, pinned: false)])
        let stored = try #require(try await store.workspace(id: rows[0].id))
        #expect(stored.pinned)
        #expect(stored.sortOrder == 4)
    }

    @Test("a workspace that stops being the orchestrator can be unpinned again")
    func stepDown() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        try await store.setOrchestrator(false, workspaceID: rows[0].id)
        try await store.update(workspaceID: rows[0].id) { $0.pinned = false }

        let stored = try #require(try await store.workspace(id: rows[0].id))
        #expect(!stored.isOrchestrator)
        #expect(!stored.pinned)
        try await store.setOrchestrator(true, workspaceID: rows[1].id)
        #expect(try await store.workspace(id: rows[1].id)?.isOrchestrator == true)
    }

    @Test("an unrelated write does not roll the flag back")
    func otherWritesKeepFlag() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        try await store.updateDiffStat(workspaceID: rows[0].id, additions: 1, deletions: 1, files: 1)
        try await store.update(workspaceID: rows[0].id) { $0.name = "renamed" }

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == true)
    }

    @Test("deleting archived workspaces in bulk never deletes an orchestrator")
    func bulkDeleteSkipsOrchestrator() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)
        try await store.update(workspaceID: rows[0].id) { $0.archive() }
        try await store.update(workspaceID: rows[1].id) { $0.archive() }

        let deleted = try await store.deleteArchivedWorkspaces(ids: [rows[0].id, rows[1].id])

        #expect(deleted == [rows[1].id])
        #expect(try await store.workspace(id: rows[0].id) != nil)
    }
}
