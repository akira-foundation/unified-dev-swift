import Testing
import Foundation
@testable import Core

extension SessionSegmentRewindTests {
    private func answer(_ store: Store, _ session: Session, _ text: String) async throws {
        let line = #"{"type":"assistant","message":{"content":[{"type":"text","text":"\#(text)"}]}}"#
        try await append(store, session, .assistantText, line)
    }

    private func deliver(_ store: Store, _ session: Session) async throws {
        let active = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.acknowledgeHandoff(sessionID: session.id, fromSegment: active.id, carriedDelta: true)
    }

    private func nextDelta(_ store: Store, _ session: Session, delivering seq: Int? = nil) async throws -> String {
        try await store.handoffTurn("next", sessionID: session.id, deliveredSeq: seq, worktree: nil, contextWindow: nil)
    }

    @Test("a rewind to the turn that carried the delta makes the next prompt carry it again")
    func rewindToTheDeltaTurnRestoresTheDelta() async throws {
        let store = try makeTestStore("delta-main")
        let session = try await makeSession(store, agent: .claudeCode)
        try await append(store, session, .user, "old question")
        try await answer(store, session, "old answer")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let carrier = try await append(store, session, .user, "first words to codex")
        try await answer(store, session, "codex reply")
        try await deliver(store, session)
        #expect(try await nextDelta(store, session) == "next")

        try await rewind(store, session, to: carrier)
        try await append(store, session, .user, "second try")

        let delta = try await nextDelta(store, session)
        #expect(delta.contains("old question"))
        #expect(delta.contains("old answer"))
        #expect(!delta.contains("codex reply"))
    }

    @Test("a re-entered segment gets the rows it missed again after a rewind to its first turn back")
    func rewindOnAReenteredSegmentRestoresWhatItMissed() async throws {
        let store = try makeTestStore("delta-reentered")
        let session = try await makeSession(store, agent: .codex)
        try await append(store, session, .user, "codex first")
        try await answer(store, session, "codex answer")
        try await deliver(store, session)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "codex-thread" }
        _ = try await store.switchSegment(sessionID: session.id, to: claude)
        try await append(store, session, .user, "claude middle")
        try await answer(store, session, "claude middle answer")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let carrier = try await append(store, session, .user, "back in codex")
        try await answer(store, session, "back reply")
        try await deliver(store, session)

        try await rewind(store, session, to: carrier)
        try await append(store, session, .user, "again")

        let delta = try await nextDelta(store, session)
        #expect(delta.contains("claude middle"))
        #expect(delta.contains("claude middle answer"))
        #expect(!delta.contains("codex answer"))
    }

    @Test("a forked chat gets its origin again after a rewind to its first turn")
    func rewindOnAForkRestoresTheSeed() async throws {
        let store = try makeTestStore("delta-fork")
        let origin = try await makeSession(store, agent: .claudeCode)
        try await append(store, origin, .user, "origin question")
        try await answer(store, origin, "origin answer")
        let forked = try await makeSession(store, agent: .codex)
        try await store.seed(sessionID: forked.id, from: origin.id)
        let carrier = try await append(store, forked, .user, "fork first")
        try await answer(store, forked, "fork reply")
        try await deliver(store, forked)
        #expect(try await store.pendingSource(sessionID: forked.id) == nil)

        try await rewind(store, forked, to: carrier)
        try await append(store, forked, .user, "fork again")

        #expect(try await store.pendingSource(sessionID: forked.id) == origin.id)
        let delta = try await nextDelta(store, forked)
        #expect(delta.contains("origin question"))
    }

    @Test("when the first turn got no real reply and the second carried the delta, rewinding the second restores it")
    func rewindToTheSecondTurnRestoresTheDelta() async throws {
        let store = try makeTestStore("delta-second")
        let session = try await makeSession(store, agent: .claudeCode)
        try await append(store, session, .user, "old question")
        try await answer(store, session, "old answer")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        try await append(store, session, .user, "silent turn")
        let second = try await append(store, session, .user, "second turn")
        try await answer(store, session, "real reply")
        try await deliver(store, session)

        try await rewind(store, session, to: second)
        try await append(store, session, .user, "second again")

        #expect(try await nextDelta(store, session).contains("old question"))
    }

    @Test("a rewind to a turn after the one that carried the delta leaves the delta delivered")
    func rewindToALaterTurnDoesNotRestore() async throws {
        let store = try makeTestStore("delta-later")
        let session = try await makeSession(store, agent: .claudeCode)
        try await append(store, session, .user, "old question")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        try await append(store, session, .user, "carrier")
        try await answer(store, session, "carrier reply")
        try await deliver(store, session)
        let later = try await append(store, session, .user, "later turn")
        try await answer(store, session, "later reply")
        let active = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.acknowledgeHandoff(sessionID: session.id, fromSegment: active.id, carriedDelta: false)

        try await rewind(store, session, to: later)
        let again = try await append(store, session, .user, "later again")

        let delta = try await nextDelta(store, session, delivering: again)
        #expect(delta == "next")
        #expect(try await cursors(store, session).last == later - 1)
    }
}
