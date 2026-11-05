import Testing
import Foundation
@testable import Core

@Suite("Session segment store", .tags(.persistence), .scratchDirectory)
struct SessionSegmentStoreTests {
    private let work = AgentAccountRow(
        id: AgentAccountID("work"), provider: .claudeCode,
        directory: "/accounts/claudeCode/work", label: "Work",
        createdAt: Date(timeIntervalSince1970: 1_000)
    )

    private func makeSession(_ store: Store, messages: Int) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let session = try await store.upsert(Session(workspaceID: workspace.id))
        for _ in 0..<messages {
            try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: Data())
        }
        return session
    }

    private func reopenedAfterRewind(_ path: String) async throws -> Store {
        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(try raw.readUserVersion() - 1)
        try raw.execute("DROP TABLE session_segments;")
        return try Store(path: path)
    }

    @Test("the migration gives every session one active segment at its last message")
    func migrationGivesEverySessionOneActiveSegment() async throws {
        let path = TestScratch.unique("segments-migrate") + ".sqlite"
        let store = try Store(path: path)
        let session = try await makeSession(store, messages: 3)

        let reopened = try await reopenedAfterRewind(path)

        let segment = try #require(try await reopened.activeSegment(sessionID: session.id))
        #expect(segment.cursorSeq == 2)
        #expect(segment.isActive)
        #expect(segment.agentKind == session.agentKind)
        #expect(segment.model == session.model)
        #expect(segment.effort == session.effort)
        #expect(try await reopened.segments(sessionID: session.id) == [segment])
    }

    @Test("a session with no messages starts its cursor at minus one")
    func sessionWithNoMessagesHasCursorMinusOne() async throws {
        let path = TestScratch.unique("segments-empty") + ".sqlite"
        let store = try Store(path: path)
        let session = try await makeSession(store, messages: 0)

        let reopened = try await reopenedAfterRewind(path)

        #expect(try await reopened.activeSegment(sessionID: session.id)?.cursorSeq == -1)
    }

    @Test("a second active segment for one chat is refused")
    func onlyOneSegmentCanBeActive() async throws {
        let path = TestScratch.unique("segments-unique") + ".sqlite"
        let store = try Store(path: path)
        let session = try await makeSession(store, messages: 0)
        let reopened = try await reopenedAfterRewind(path)
        _ = try #require(try await reopened.activeSegment(sessionID: session.id))

        let raw = try SQLiteDatabase(path: path)
        #expect(throws: (any Error).self) {
            try raw.execute("""
                INSERT INTO session_segments (id, session_id, agent_kind, model, is_active, created_at)
                VALUES ('second', '\(session.id.rawValue)', 'claudeCode', 'opus', 1, 0)
                """)
        }
        try raw.execute("""
            INSERT INTO session_segments (id, session_id, agent_kind, model, is_active, created_at)
            VALUES ('parked', '\(session.id.rawValue)', 'claudeCode', 'opus', 0, 0)
            """)
        #expect(try await reopened.segments(sessionID: session.id).count == 2)
    }

    @Test("the cursor never moves backwards when advanced, and a reset returns it to minus one")
    func advanceCursorNeverMovesBackwards() async throws {
        let path = TestScratch.unique("segments-advance") + ".sqlite"
        let store = try Store(path: path)
        let session = try await makeSession(store, messages: 0)
        let reopened = try await reopenedAfterRewind(path)
        let segment = try #require(try await reopened.activeSegment(sessionID: session.id))

        try await reopened.advanceCursor(segmentID: segment.id, toSeq: 5)
        try await reopened.advanceCursor(segmentID: segment.id, toSeq: 3)
        #expect(try await reopened.activeSegment(sessionID: session.id)?.cursorSeq == 5)

        try await reopened.resetCursor(segmentID: segment.id)
        #expect(try await reopened.activeSegment(sessionID: session.id)?.cursorSeq == -1)
    }

    @Test("seeding records the source chat on the active segment only")
    func seedWritesTheActiveSegment() async throws {
        let path = TestScratch.unique("segments-seed") + ".sqlite"
        let store = try Store(path: path)
        let session = try await makeSession(store, messages: 0)
        let source = try await store.upsert(Session(workspaceID: session.workspaceID))
        let reopened = try await reopenedAfterRewind(path)

        try await reopened.seed(sessionID: session.id, from: source.id)

        #expect(try await reopened.activeSegment(sessionID: session.id)?.seedSessionID == source.id)
    }

    @Test("forgetting an account clears the history its segments pointed at")
    func forgettingAnAccountClearsItsSegmentsHistory() async throws {
        let path = TestScratch.unique("segments-forget") + ".sqlite"
        let store = try Store(path: path)
        try await store.add(work)
        let session = try await makeSession(store, messages: 2)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "native" }
        let raw = try SQLiteDatabase(path: path)
        try raw.execute("UPDATE sessions SET account_id = 'work' WHERE id = '\(session.id.rawValue)'")
        let reopened = try await reopenedAfterRewind(path)
        let before = try #require(try await reopened.activeSegment(sessionID: session.id))
        #expect(before.accountID == work.id)
        #expect(before.agentSessionID == "native")
        #expect(before.cursorSeq == 1)

        try await reopened.forgetAgentAccount(work.id)

        let after = try #require(try await reopened.activeSegment(sessionID: session.id))
        #expect(after.accountID == nil)
        #expect(after.agentSessionID == nil)
        #expect(after.cursorSeq == -1)
    }
}
