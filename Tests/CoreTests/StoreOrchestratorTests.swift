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

    private func refusesForLiveWork(_ attempt: () async throws -> Void) async {
        let error = await #expect(throws: WorkspaceError.self) { try await attempt() }
        guard case .orchestratorHasLiveWork = error else {
            Issue.record("expected the live work refusal, got \(String(describing: error))")
            return
        }
    }

    private func chat(
        in workspace: Workspace, _ kind: AgentKind, _ state: SessionState, parent: SessionID? = nil
    ) -> Session {
        var chat = Session(workspaceID: workspace.id, parentSessionID: parent, title: "Working")
        chat.agentKind = kind
        chat.state = state
        return chat
    }

    @Test("the role does not land on a workspace with a chat mid turn",
          arguments: [AgentKind.claudeCode, .codex, .grok], [SessionState.running, .waiting])
    func midTurnChatKeepsRoleOff(_ kind: AgentKind, _ state: SessionState) async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.upsert(chat(in: rows[0], kind, state))

        await refusesForLiveWork { try await store.setOrchestrator(true, workspaceID: rows[0].id) }

        let stored = try #require(try await store.workspace(id: rows[0].id))
        #expect(!stored.isOrchestrator)
        #expect(!stored.pinned)
    }

    @Test("a crew member mid turn keeps the role off as well")
    func crewMemberKeepsRoleOff() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        let lead = try await store.upsert(chat(in: rows[0], .claudeCode, .idle))
        try await store.upsert(chat(in: rows[0], .codex, .running, parent: lead.id))

        await refusesForLiveWork { try await store.setOrchestrator(true, workspaceID: rows[0].id) }

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == false)
    }

    @Test("an open terminal chat keeps the role off when every stored chat is idle")
    func openTerminalChatKeepsRoleOff() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.upsert(chat(in: rows[0], .claudeCode, .idle))

        await refusesForLiveWork {
            try await store.setOrchestrator(true, workspaceID: rows[0].id, hasLiveWork: true)
        }

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == false)
    }

    @Test("chats at rest let the role land",
          arguments: [AgentKind.claudeCode, .codex, .grok], [SessionState.idle, .failed, .cancelled])
    func chatsAtRestAllowTheRole(_ kind: AgentKind, _ state: SessionState) async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.upsert(chat(in: rows[0], kind, state))

        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == true)
    }

    @Test("work in another workspace of the project does not hold the role back")
    func otherWorkspaceDoesNotCount() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.upsert(chat(in: rows[1], .claudeCode, .running))

        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == true)
    }

    @Test("stepping down is never held back by a chat mid turn")
    func steppingDownIsNotHeldBack() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)
        try await store.upsert(chat(in: rows[0], .claudeCode, .running))

        try await store.setOrchestrator(false, workspaceID: rows[0].id, hasLiveWork: true)

        #expect(try await store.workspace(id: rows[0].id)?.isOrchestrator == false)
    }

    @Test("a project that has an orchestrator says so rather than asking for a handover")
    func existingOrchestratorIsTheAnswer() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)
        try await store.upsert(chat(in: rows[1], .claudeCode, .running))

        let error = await #expect(throws: WorkspaceError.self) {
            try await store.setOrchestrator(true, workspaceID: rows[1].id)
        }

        guard case .orchestratorRefused = error else {
            Issue.record("expected the one orchestrator refusal, got \(String(describing: error))")
            return
        }
    }

    @Test("a launch reads the role from the row as it stands")
    func launchReadsTheRow() async throws {
        let store = try makeTestStore("orchestrator")
        let rows = try await seed(store)

        #expect(await store.orchestratesAtLaunch(workspaceID: rows[0].id) == false)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        #expect(await store.orchestratesAtLaunch(workspaceID: rows[0].id))
        #expect(await store.orchestratesAtLaunch(workspaceID: rows[1].id) == false)
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

    @Test("a database that calls itself migrated but lost the column gets it back, index and all")
    func repairPutsTheColumnBack() async throws {
        let path = TestScratch.unique("orchestrator-repair") + ".sqlite"
        let store = try Store(path: path)
        let rows = try await seed(store)

        let raw = try SQLiteDatabase(path: path)
        try raw.execute("DROP INDEX IF EXISTS workspaces_one_orchestrator;")
        try raw.execute("ALTER TABLE workspaces DROP COLUMN is_orchestrator;")

        let reopened = try Store(path: path)
        #expect(try await reopened.workspace(id: rows[0].id)?.isOrchestrator == false)
        try await reopened.setOrchestrator(true, workspaceID: rows[0].id)
        var second = try #require(try await reopened.workspace(id: rows[1].id))
        second.isOrchestrator = true
        await #expect(throws: (any Error).self) { try await reopened.upsert(second) }
    }

    @Test("replaying every migration over a database that has the column keeps the flag")
    func replayKeepsTheFlag() async throws {
        let path = TestScratch.unique("orchestrator-replay") + ".sqlite"
        let store = try Store(path: path)
        let rows = try await seed(store)
        try await store.setOrchestrator(true, workspaceID: rows[0].id)

        try SQLiteDatabase(path: path).setUserVersion(0)

        let reopened = try Store(path: path)
        #expect(try await reopened.workspace(id: rows[0].id)?.isOrchestrator == true)
    }

    @Test("an unknown workspace cannot be made the orchestrator")
    func unknown() async throws {
        let store = try makeTestStore("orchestrator")
        #expect(try await store.setOrchestrator(true, workspaceID: WorkspaceID("nowhere")) == nil)
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
