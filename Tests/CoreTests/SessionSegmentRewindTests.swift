import Testing
import Foundation
@testable import Core

@Suite("Session segment rewind", .tags(.persistence), .scratchDirectory)
struct SessionSegmentRewindTests {
    let claude = SessionSegmentTarget(agentKind: .claudeCode, accountID: nil, model: "opus", effort: "")
    let codex = SessionSegmentTarget(agentKind: .codex, accountID: nil, model: "gpt-5", effort: "high")
    let grok = SessionSegmentTarget(agentKind: .grok, accountID: nil, model: "grok-4.6", effort: "")

    func makeSession(_ store: Store, agent: AgentKind = .codex) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, agentKind: agent))
    }

    func userPayload(_ text: String) -> Data {
        let json = JSONValue.object(["type": .string("user"), "message": .object(["content": .string(text)])])
        return Data(json.compactJSON.utf8)
    }

    @discardableResult
    func append(_ store: Store, _ session: Session, _ kind: MessageKind, _ text: String = "{}") async throws -> Int {
        let payload = kind == .user ? userPayload(text) : Data(text.utf8)
        return try await store.appendNext(sessionID: session.id, kind: kind, payload: payload).seq
    }

    func fill(_ store: Store, _ session: Session, through seq: Int) async throws {
        while try await store.messages(sessionID: session.id).count <= seq {
            try await append(store, session, .notice)
        }
    }

    func rewind(_ store: Store, _ session: Session, to seq: Int) async throws {
        let checkpoint = TurnCheckpoint(sessionID: session.id, startSeq: seq, before: GitSnapshot(sessionID: session.id))
        _ = try await store.prepareTranscriptRewind(checkpoint)
        var journal = CheckpointRewind(checkpoint: checkpoint, recovery: nil, restoringFiles: false)
        try await store.saveCheckpointRewind(journal)
        journal.stage = .providerReverted
        try await store.saveCheckpointRewind(journal)
        _ = try await store.completeTranscriptRewind(sessionID: session.id)
    }

    func cursors(_ store: Store, _ session: Session) async throws -> [Int] {
        try await store.segments(sessionID: session.id).map(\.cursorSeq)
    }

    @Test("a rewind pulls every cursor back to the cut and leaves the ones already behind it")
    func rewindClampsEveryCursor() async throws {
        let store = try makeTestStore("rewind-clamp")
        let session = try await makeSession(store)
        try await append(store, session, .user, "first")
        let first = try #require(try await store.activeSegment(sessionID: session.id))
        _ = try await store.switchSegment(sessionID: session.id, to: claude)
        let second = try #require(try await store.activeSegment(sessionID: session.id))
        _ = try await store.switchSegment(sessionID: session.id, to: grok)
        let third = try #require(try await store.activeSegment(sessionID: session.id))
        try await fill(store, session, through: 29)
        try await append(store, session, .user, "the cut")
        try await fill(store, session, through: 40)
        try await store.advanceCursor(segmentID: first.id, toSeq: 35)
        try await store.advanceCursor(segmentID: third.id, toSeq: 40)

        try await rewind(store, session, to: 30)

        let after = Dictionary(uniqueKeysWithValues: try await store.segments(sessionID: session.id).map { ($0.id, $0.cursorSeq) })
        #expect(after[first.id] == 29)
        #expect(after[second.id] == -1)
        #expect(after[third.id] == 29)
    }

    @Test("a rewind to before the divider is refused and changes nothing")
    func rewindBeforeADividerIsRefused() async throws {
        let store = try makeTestStore("rewind-divider")
        let session = try await makeSession(store)
        let early = try await append(store, session, .user, "ran before the switch")
        try await append(store, session, .result)
        _ = try await store.switchSegment(sessionID: session.id, to: claude)
        let entered = try #require(try await store.activeSegment(sessionID: session.id)).enteredSeq
        let before = try await store.messages(sessionID: session.id).count
        let checkpoint = TurnCheckpoint(sessionID: session.id, startSeq: early, before: GitSnapshot(sessionID: session.id))

        let error = await #expect(throws: ConversationRewindError.self) {
            _ = try await store.prepareTranscriptRewind(checkpoint)
        }

        #expect(early < entered)
        #expect(error == .crossesHandoff)
        #expect(error?.errorDescription == "This turn ran before the agent changed, so it cannot be rewound.")
        #expect(try await store.messages(sessionID: session.id).count == before)
        #expect(try await store.transcriptRewindBackup(sessionID: session.id) == nil)
    }

    @Test("a rewind to a turn after the divider still works, resuming row included")
    func rewindAfterTheDividerStillWorks() async throws {
        let store = try makeTestStore("rewind-after")
        let session = try await makeSession(store)
        try await append(store, session, .user, "before")
        _ = try await store.switchSegment(sessionID: session.id, to: claude)
        let entered = try #require(try await store.activeSegment(sessionID: session.id)).enteredSeq
        try await append(store, session, .handoff, String(decoding: HandoffMark.resuming.payload, as: UTF8.self))
        try await append(store, session, .result)
        let target = try await append(store, session, .user, "after")
        let resuming = try await append(store, session, .handoff, String(decoding: HandoffMark.resuming.payload, as: UTF8.self))
        try await append(store, session, .result)

        try await rewind(store, session, to: target)

        let kept = try await store.messages(sessionID: session.id).map(\.seq)
        #expect(kept.last == target - 1)
        #expect(!kept.contains(resuming))
        #expect(kept.contains(entered))
        #expect(try await store.activeSegment(sessionID: session.id)?.enteredSeq == entered)
    }

    @Test("a rewind after a switch to an agent that never spoke leaves that segment alone")
    func rewindAfterAnEmptySegment() async throws {
        let store = try makeTestStore("rewind-empty")
        let session = try await makeSession(store)
        try await append(store, session, .user, "codex turn")
        _ = try await store.switchSegment(sessionID: session.id, to: claude)
        let empty = try #require(try await store.activeSegment(sessionID: session.id))
        _ = try await store.switchSegment(sessionID: session.id, to: grok)
        let target = try await append(store, session, .user, "grok turn")
        try await append(store, session, .result)

        try await rewind(store, session, to: target)

        let after = try #require(try await store.segments(sessionID: session.id).first { $0.id == empty.id })
        #expect(after.cursorSeq == -1)
        #expect(after.agentSessionID == nil)
        #expect(try await store.activeSegment(sessionID: session.id)?.agentKind == .grok)
        #expect(try await store.messages(sessionID: session.id).filter { $0.kind == .handoff }.count == 2)
    }

    @Test("a stale runner cannot reset the cursor of a segment that is parked")
    func resetCursorIgnoresAParkedSegment() async throws {
        let store = try makeTestStore("rewind-reset")
        let session = try await makeSession(store)
        let first = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.advanceCursor(segmentID: first.id, toSeq: 12)
        _ = try await store.switchSegment(sessionID: session.id, to: claude)
        let active = try #require(try await store.activeSegment(sessionID: session.id))

        try await store.resetCursor(segmentID: first.id)
        try await store.advanceCursor(segmentID: active.id, toSeq: 3)
        try await store.resetCursor(segmentID: active.id)

        let all = Dictionary(uniqueKeysWithValues: try await store.segments(sessionID: session.id).map { ($0.id, $0.cursorSeq) })
        #expect(all[first.id] == 12)
        #expect(all[active.id] == -1)
    }
}
