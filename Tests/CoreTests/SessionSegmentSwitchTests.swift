import Testing
import Foundation
@testable import Core

@Suite("Session segment switch", .tags(.persistence), .scratchDirectory)
struct SessionSegmentSwitchTests {
    private let work = AgentAccountRow(
        id: AgentAccountID("work"), provider: .claudeCode,
        directory: "/accounts/claudeCode/work", label: "Work",
        createdAt: Date(timeIntervalSince1970: 1_000)
    )

    private let codex = SessionSegmentTarget(agentKind: .codex, accountID: nil, model: "gpt-5", effort: "high")
    private let claude = SessionSegmentTarget(agentKind: .claudeCode, accountID: nil, model: "opus", effort: "")

    private func makeSession(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    private func handoffs(_ store: Store, _ session: Session) async throws -> [Message] {
        try await store.messages(sessionID: session.id).filter { $0.kind == .handoff }
    }

    @Test("switching to a new provider starts with no history")
    func switchingToANewProviderStartsWithNoHistory() async throws {
        let store = try makeTestStore("switch-new")
        let session = try await makeSession(store)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "c1"; $0.contextTokens = 900 }

        let switched = try await store.switchSegment(sessionID: session.id, to: codex)

        #expect(switched.agentKind == .codex)
        #expect(switched.agentSessionID == nil)
        #expect(switched.contextTokens == 0)
        #expect(switched.model == "gpt-5")
        #expect(try await store.messages(sessionID: session.id).last?.kind == .handoff)
    }

    @Test("returning restores the native session and the cursor")
    func returningRestoresTheNativeSessionAndCursor() async throws {
        let store = try makeTestStore("switch-return")
        let session = try await makeSession(store)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "c1" }
        let first = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.advanceCursor(segmentID: first.id, toSeq: 40)

        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let back = try await store.switchSegment(sessionID: session.id, to: claude)

        let active = try #require(try await store.activeSegment(sessionID: session.id))
        #expect(back.agentSessionID == "c1")
        #expect(active.id == first.id)
        #expect(active.cursorSeq == 40)
        #expect(try await store.segments(sessionID: session.id).count == 2)
    }

    @Test("counters belong to their segment")
    func countersBelongToTheirSegment() async throws {
        let store = try makeTestStore("switch-counters")
        let session = try await makeSession(store)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "c1"; $0.inputTokens = 100 }

        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let inCodex = try await store.update(sessionID: session.id) { $0.inputTokens = 7 }
        let back = try await store.switchSegment(sessionID: session.id, to: claude)

        #expect(inCodex?.inputTokens == 7)
        #expect(back.inputTokens == 100)
    }

    @Test("switching twice without speaking leaves two dividers")
    func switchingTwiceWithoutSpeakingLeavesTwoDividers() async throws {
        let store = try makeTestStore("switch-twice")
        let session = try await makeSession(store)

        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        _ = try await store.switchSegment(sessionID: session.id, to: claude)

        #expect(try await handoffs(store, session).count == 2)
    }

    @Test("switching to the active target changes nothing")
    func switchingToTheActiveTargetChangesNothing() async throws {
        let store = try makeTestStore("switch-same")
        let session = try await makeSession(store)
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let before = try await store.messages(sessionID: session.id).count

        _ = try await store.switchSegment(sessionID: session.id, to: codex)

        #expect(try await store.messages(sessionID: session.id).count == before)
        #expect(try await store.segments(sessionID: session.id).count == 2)
    }

    @Test("the same provider under another account is another segment")
    func sameProviderOtherAccountIsAnotherSegment() async throws {
        let store = try makeTestStore("switch-account")
        try await store.add(work)
        let session = try await makeSession(store)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "c1" }
        let target = SessionSegmentTarget(agentKind: .claudeCode, accountID: work.id, model: "opus", effort: "")

        let switched = try await store.switchSegment(sessionID: session.id, to: target)

        #expect(switched.accountID == work.id)
        #expect(switched.agentSessionID == nil)
        #expect(try await store.segments(sessionID: session.id).count == 2)
    }

    @Test("a segment whose account was forgotten never matches a target")
    func forgottenAccountNeverMatches() async throws {
        let store = try makeTestStore("switch-forgotten")
        try await store.add(work)
        let session = try await makeSession(store)
        let target = SessionSegmentTarget(agentKind: .claudeCode, accountID: work.id, model: "opus", effort: "")
        _ = try await store.switchSegment(sessionID: session.id, to: target)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "w1" }
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        try await store.forgetAgentAccount(work.id)

        _ = try await store.switchSegment(sessionID: session.id, to: SessionSegmentTarget(
            agentKind: .claudeCode, accountID: nil, model: "opus", effort: ""
        ))

        #expect(try await store.segments(sessionID: session.id).count == 4)
    }
}
