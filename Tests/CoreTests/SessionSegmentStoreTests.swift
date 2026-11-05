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

    @Test("a seeded session names its source on its active segment")
    func seededSessionNamesItsSource() async throws {
        let store = try makeTestStore("segments-seeded")
        let source = try await makeSession(store, messages: 2)
        let forked = try await store.upsert(Session(workspaceID: try #require(source.workspaceID)))

        try await store.seed(sessionID: forked.id, from: source.id)

        #expect(try await store.activeSegment(sessionID: forked.id)?.seedSessionID == source.id)
        #expect(try await store.activeSegment(sessionID: source.id)?.seedSessionID == nil)
    }

    @Test("a seed not yet delivered follows the chat to the next agent")
    func anUndeliveredSeedFollowsASwitch() async throws {
        let store = try makeTestStore("segments-seed-moves")
        let source = try await makeSession(store, messages: 0)
        try await store.appendNext(
            sessionID: source.id, kind: .user,
            payload: Data(#"{"type":"user","message":{"content":"words from the source"}}"#.utf8)
        )
        let forked = try await store.upsert(Session(
            workspaceID: try #require(source.workspaceID), model: "gpt", agentKind: .codex
        ))
        try await store.seed(sessionID: forked.id, from: source.id)

        _ = try await store.switchSegment(sessionID: forked.id, to: SessionSegmentTarget(
            agentKind: .grok, accountID: nil, model: "grok-4", effort: ""
        ))

        #expect(try await store.activeSegment(sessionID: forked.id)?.seedSessionID == source.id)
        let turn = try await store.handoffTurn(
            "next", sessionID: forked.id, deliveredSeq: nil, worktree: nil, contextWindow: nil
        )
        #expect(turn.contains("words from the source"))
        let parked = try await store.segments(sessionID: forked.id).filter { !$0.isActive }
        #expect(parked.allSatisfy { $0.seedSessionID == nil })
    }

    @Test("a seeded chat whose agent died unheard hands the owner's message to the next one, whole")
    func anUnheardMessageInASeededChatReachesTheNextAgent() async throws {
        let store = try makeTestStore("segments-seed-unheard")
        let source = try await makeSession(store, messages: 0)
        let padding = String(repeating: "source padding ", count: 80)
        for index in 0..<20 {
            try await store.appendNext(
                sessionID: source.id, kind: .user,
                payload: Data(#"{"type":"user","message":{"content":"source \#(index) \#(padding)"}}"#.utf8)
            )
        }
        let forked = try await store.upsert(Session(
            workspaceID: try #require(source.workspaceID), model: "gpt", agentKind: .codex
        ))
        try await store.seed(sessionID: forked.id, from: source.id)
        let message = "the owner asked this" + String(repeating: " and more", count: 150)
        let delivery = try await store.enqueueDelivery(Delivery(targetSessionID: forked.id, body: message))
        #expect(try await store.claimDelivery(id: delivery.id))

        _ = try await store.switchSegment(sessionID: forked.id, to: SessionSegmentTarget(
            agentKind: .grok, accountID: nil, model: "grok-4", effort: ""
        ))
        let turn = try await store.handoffTurn(
            "next", sessionID: forked.id, deliveredSeq: nil, worktree: nil, contextWindow: 16_000
        )

        #expect(turn.contains(message))
        #expect(turn.contains("source 19"))
        #expect(turn.contains(source.id.rawValue))
        #expect(turn.contains(forked.id.rawValue))
        #expect(turn.count <= 16_000 + "next".count + 2)
    }

    @Test("a seeded chat's own new message is not read back to it")
    func aSeededChatLeavesOutTheMessageBeingSent() async throws {
        let store = try makeTestStore("segments-seed-current")
        let source = try await makeSession(store, messages: 1)
        let forked = try await store.upsert(Session(
            workspaceID: try #require(source.workspaceID), model: "gpt", agentKind: .codex
        ))
        try await store.seed(sessionID: forked.id, from: source.id)
        let delivery = try await store.enqueueDelivery(Delivery(targetSessionID: forked.id, body: "the message itself"))
        #expect(try await store.claimDelivery(id: delivery.id))
        let seq = try #require(try await store.delivery(id: delivery.id)?.deliveredSeq)

        let turn = try await store.handoffTurn(
            "the message itself", sessionID: forked.id, deliveredSeq: seq, worktree: nil, contextWindow: nil
        )

        #expect(turn.components(separatedBy: "the message itself").count == 2)
    }

    @Test("a seed already delivered does not come back on a switch")
    func aDeliveredSeedStaysDelivered() async throws {
        let store = try makeTestStore("segments-seed-spent")
        let source = try await makeSession(store, messages: 1)
        let forked = try await store.upsert(Session(
            workspaceID: try #require(source.workspaceID), model: "gpt", agentKind: .codex
        ))
        try await store.seed(sessionID: forked.id, from: source.id)
        let first = try #require(try await store.activeSegment(sessionID: forked.id)).id
        try await store.acknowledgeHandoff(sessionID: forked.id, fromSegment: first, carriedDelta: false)

        _ = try await store.switchSegment(sessionID: forked.id, to: SessionSegmentTarget(
            agentKind: .grok, accountID: nil, model: "grok-4", effort: ""
        ))

        #expect(try await store.activeSegment(sessionID: forked.id)?.seedSessionID == nil)
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

    @Test("a session created through upsert starts with one active segment")
    func aNewSessionStartsWithOneActiveSegment() async throws {
        let store = try makeTestStore("segments-new")
        try await store.add(work)
        let session = try await makeSession(store, messages: 0)
        var custom = Session(workspaceID: session.workspaceID)
        custom.agentKind = .codex
        custom.model = "gpt-x"
        custom.effort = "low"
        custom.accountID = nil
        let created = try await store.upsert(custom)

        let segments = try await store.segments(sessionID: created.id)

        let segment = try #require(segments.first)
        #expect(segments.count == 1)
        #expect(segment.isActive)
        #expect(segment.agentKind == .codex)
        #expect(segment.accountID == created.accountID)
        #expect(segment.model == "gpt-x")
        #expect(segment.effort == "low")
        #expect(segment.cursorSeq == -1)
    }

    @Test("upserting an existing session adds no segment and leaves the cursor alone")
    func upsertingAnExistingSessionAddsNoSegment() async throws {
        let store = try makeTestStore("segments-again")
        let session = try await makeSession(store, messages: 0)
        let segment = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.advanceCursor(segmentID: segment.id, toSeq: 4)

        try await store.upsert(session)

        let segments = try await store.segments(sessionID: session.id)
        #expect(segments.count == 1)
        #expect(segments.first?.cursorSeq == 4)
    }

    @Test("seeding reaches a session created after the migration")
    func seedReachesANewSession() async throws {
        let store = try makeTestStore("segments-seed-new")
        let session = try await makeSession(store, messages: 0)
        let source = try await store.upsert(Session(workspaceID: session.workspaceID))

        try await store.seed(sessionID: session.id, from: source.id)

        #expect(try await store.activeSegment(sessionID: session.id)?.seedSessionID == source.id)
    }

    private func expectOneActiveSegment(_ store: Store, _ session: Session) async throws {
        let segments = try await store.segments(sessionID: session.id)
        #expect(segments.count == 1)
        #expect(segments.first?.isActive == true)
        #expect(segments.first?.agentKind == session.agentKind)
    }

    @Test("a side conversation opens with its own active segment")
    func sideConversationGetsASegment() async throws {
        let store = try makeTestStore("segments-side")
        let parent = try await makeSession(store, messages: 0)

        let child = try await store.openSideConversation(parentID: parent.id)

        try await expectOneActiveSegment(store, child)
    }

    @Test("replacing a workspace chat gives the replacement a segment and keeps the old one")
    func replacingAWorkspaceChatGetsASegment() async throws {
        let store = try makeTestStore("segments-replace-workspace")
        let old = try await makeSession(store, messages: 0)

        let next = try await store.replaceWorkspaceConversation(id: old.id, controls: ComposerControls())

        try await expectOneActiveSegment(store, next)
        #expect(try await store.segments(sessionID: old.id).count == 1)
    }

    @Test("creating an Ask chat gives it a segment")
    func creatingAnAskChatGetsASegment() async throws {
        let store = try makeTestStore("segments-ask-create")

        let chat = try await store.createAskConversation(directory: "/ask")

        try await expectOneActiveSegment(store, chat)
    }

    @Test("replacing an Ask chat gives the replacement a segment")
    func replacingAnAskChatGetsASegment() async throws {
        let store = try makeTestStore("segments-ask-replace")
        let first = try await store.createAskConversation(directory: "/ask")

        let next = try await store.replaceAskConversation(id: first.id, controls: ComposerControls())

        try await expectOneActiveSegment(store, next)
    }
}
