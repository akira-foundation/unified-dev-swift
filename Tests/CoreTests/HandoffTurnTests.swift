import Testing
import Foundation
@testable import Core

@Suite("Handoff turn", .tags(.persistence), .scratchDirectory)
struct HandoffTurnTests {
    private let codex = SessionSegmentTarget(agentKind: .codex, accountID: nil, model: "gpt-5", effort: "high")

    private func makeSession(_ store: Store, agent: AgentKind = .claudeCode) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, agentKind: agent))
    }

    private func say(_ store: Store, _ session: Session, _ text: String) async throws {
        let json = JSONValue.object([
            "type": .string("user"),
            "message": .object(["content": .string(text)]),
        ])
        try await store.appendNext(sessionID: session.id, kind: .user, payload: Data(json.compactJSON.utf8))
    }

    private func acknowledge(_ store: Store, _ session: Session) async throws {
        let active = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.acknowledgeHandoff(sessionID: session.id, fromSegment: active.id, carriedDelta: false)
    }

    private func turn(
        _ store: Store, _ session: Session, deliveredSeq: Int? = nil, text: String = "PROMPT"
    ) async throws -> String {
        try await store.handoffTurn(
            text, sessionID: session.id, deliveredSeq: deliveredSeq, worktree: nil, contextWindow: nil
        )
    }

    @Test("the prompt being delivered is not in its own delta")
    func theCurrentPromptIsNotInItsOwnDelta() async throws {
        let store = try makeTestStore("handoff-own-prompt")
        let session = try await makeSession(store)
        try await say(store, session, "earlier words")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let delivery = try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "PROMPT"))
        let claimed = try await store.claimDelivery(id: delivery.id)
        #expect(claimed)
        let seq = try #require(try await store.delivery(id: delivery.id)?.deliveredSeq)

        let prompt = try await turn(store, session, deliveredSeq: seq)

        #expect(prompt.contains("earlier words"))
        #expect(prompt.hasSuffix("\n\nPROMPT"))
        #expect(prompt.components(separatedBy: "PROMPT").count == 2)
    }

    @Test("a returning agent gets only what it missed")
    func aReturningAgentGetsOnlyWhatItMissed() async throws {
        let store = try makeTestStore("handoff-returning")
        let session = try await makeSession(store)
        for number in 0...70 { try await say(store, session, "line-\(number)-end") }
        let segment = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.advanceCursor(segmentID: segment.id, toSeq: 40)

        let prompt = try await turn(store, session)

        #expect(!prompt.contains("line-40-end"))
        #expect(prompt.contains("line-41-end"))
        #expect(prompt.contains("line-70-end"))
    }

    @Test("an unacknowledged delta is sent again")
    func unacknowledgedDeltaIsSentAgain() async throws {
        let store = try makeTestStore("handoff-unacknowledged")
        let session = try await makeSession(store)
        try await say(store, session, "earlier words")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)

        let first = try await turn(store, session)
        let second = try await turn(store, session)

        #expect(first.contains("earlier words"))
        #expect(second == first)
    }

    @Test("an acknowledged delta is not repeated")
    func acknowledgedDeltaIsNotRepeated() async throws {
        let store = try makeTestStore("handoff-acknowledged")
        let session = try await makeSession(store)
        try await say(store, session, "earlier words")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        _ = try await turn(store, session)

        try await acknowledge(store, session)

        #expect(try await turn(store, session) == "PROMPT")
    }

    @Test("acknowledging moves the active cursor and leaves a parked one")
    func acknowledgingLeavesAParkedCursor() async throws {
        let store = try makeTestStore("handoff-parked")
        let session = try await makeSession(store)
        let claude = try #require(try await store.activeSegment(sessionID: session.id))
        try await say(store, session, "earlier words")
        _ = try await store.switchSegment(sessionID: session.id, to: codex)

        try await acknowledge(store, session)

        let segments = try await store.segments(sessionID: session.id)
        #expect(segments.first { $0.id == claude.id }?.cursorSeq == -1)
        #expect(segments.first { $0.isActive }?.cursorSeq == 1)
    }

    @Test("an agent that saw everything gets the prompt unchanged")
    func agentThatSawEverythingGetsThePromptUnchanged() async throws {
        let store = try makeTestStore("handoff-seen")
        let session = try await makeSession(store)
        try await say(store, session, "earlier words")
        try await acknowledge(store, session)

        #expect(try await turn(store, session) == "PROMPT")
        #expect(try await store.handoffIsDue(sessionID: session.id, deliveredSeq: nil) == false)
    }

    @Test("a brand new chat sends its first prompt unchanged")
    func aNewChatSendsItsFirstPromptUnchanged() async throws {
        let store = try makeTestStore("handoff-first")
        let session = try await makeSession(store)
        try await say(store, session, "PROMPT")

        #expect(try await turn(store, session, deliveredSeq: 0) == "PROMPT")
    }

    @Test("rows the agent never had to read are not a delta", arguments: [
        MessageKind.notice, .system, .error, .suggestion, .result, .thinking,
    ])
    func housekeepingRowsAreNotADelta(kind: MessageKind) async throws {
        let store = try makeTestStore("handoff-housekeeping-\(kind.rawValue)")
        let session = try await makeSession(store)
        try await say(store, session, "earlier words")
        try await acknowledge(store, session)
        try await store.appendNext(sessionID: session.id, kind: kind, payload: Data("{}".utf8))

        #expect(try await store.handoffIsDue(sessionID: session.id, deliveredSeq: nil) == false)
        #expect(try await turn(store, session) == "PROMPT")
    }

    @Test("a seeded chat reads its source, and stops once acknowledged")
    func seededChatReadsItsSource() async throws {
        let store = try makeTestStore("handoff-seeded")
        let source = try await makeSession(store)
        try await say(store, source, "words of the source")
        let chat = try await makeSession(store, agent: .codex)
        try await say(store, chat, "PROMPT")
        try await store.seed(sessionID: chat.id, from: source.id)

        let prompt = try await turn(store, chat, deliveredSeq: 0)

        #expect(prompt.contains("words of the source"))
        #expect(prompt.contains(source.id.rawValue))
        #expect(prompt.hasSuffix("\n\nPROMPT"))

        try await acknowledge(store, chat)
        let segment = try #require(try await store.activeSegment(sessionID: chat.id))
        #expect(segment.seedSessionID == nil)
        #expect(try await turn(store, chat, deliveredSeq: 1) == "PROMPT")
    }

    @Test("a seeded chat reads a limit stop as its source's agent")
    func seededChatNamesItsSourcesAgent() async throws {
        let store = try makeTestStore("handoff-seeded-agent")
        let source = try await makeSession(store)
        try await say(store, source, "go on")
        try await store.appendNext(
            sessionID: source.id, kind: .assistantText,
            payload: Data(try fixtureLines("claude-usage-limit.ndjson")[0].utf8)
        )
        try await store.appendNext(sessionID: source.id, kind: .result, payload: Data(cleanResult.utf8))
        let chat = try await makeSession(store, agent: .codex)
        try await store.seed(sessionID: chat.id, from: source.id)

        #expect(try await turn(store, chat).contains("interrupted"))
    }

    @Test("the leaving agent is the one read for a limit stop")
    func theLeavingAgentIsReadForALimitStop() async throws {
        let store = try makeTestStore("handoff-from")
        let session = try await makeSession(store)
        try await say(store, session, "go on")
        try await store.appendNext(
            sessionID: session.id, kind: .assistantText,
            payload: Data(try fixtureLines("claude-usage-limit.ndjson")[0].utf8)
        )
        try await store.appendNext(sessionID: session.id, kind: .result, payload: Data(cleanResult.utf8))

        _ = try await store.switchSegment(sessionID: session.id, to: codex)

        let divider = try #require(try await store.messages(sessionID: session.id).last)
        #expect(HandoffMark.decode(divider.payload) == .continued(agent: .codex, model: "gpt-5", from: .claudeCode))
        #expect(try await turn(store, session).contains("interrupted"))
    }

    @Test("with no divider the chat's own agent ran the last turn")
    func noDividerReadsTheChatsOwnAgent() async throws {
        let store = try makeTestStore("handoff-own-agent")
        let session = try await makeSession(store)
        try await say(store, session, "go on")
        try await store.appendNext(
            sessionID: session.id, kind: .assistantText,
            payload: Data(try fixtureLines("claude-usage-limit.ndjson")[0].utf8)
        )
        try await store.appendNext(sessionID: session.id, kind: .result, payload: Data(cleanResult.utf8))

        #expect(try await turn(store, session).contains("interrupted"))
    }

    @Test("a small context window shrinks the delta")
    func aSmallContextWindowShrinksTheDelta() async throws {
        let store = try makeTestStore("handoff-window")
        let session = try await makeSession(store)
        try await say(store, session, String(repeating: "wide words ", count: 2_000))

        let prompt = try await store.handoffTurn(
            "PROMPT", sessionID: session.id, deliveredSeq: nil, worktree: nil, contextWindow: 1_500
        )

        #expect(prompt.count < 1_600)
        #expect(prompt.hasSuffix("\n\nPROMPT"))
    }

    private let cleanResult = #"{"type":"result","subtype":"success","is_error":false,"result":"done"}"#

    @Test("Claude, Codex, Claude: the returning agent reads only what the other one did")
    func theRealPathThroughTwoSwitches() async throws {
        let store = try makeTestStore("handoff-round-trip")
        let session = try await makeSession(store)
        try await store.update(sessionID: session.id) { $0.agentSessionID = "c1" }
        try await say(store, session, "said-to-claude")
        try await acknowledge(store, session)

        _ = try await store.switchSegment(sessionID: session.id, to: codex)
        let toCodex = try await turn(store, session)
        #expect(toCodex.contains("said-to-claude"))
        try await say(store, session, "said-to-codex")
        try await acknowledge(store, session)

        _ = try await store.switchSegment(sessionID: session.id, to: SessionSegmentTarget(
            agentKind: .claudeCode, accountID: nil, model: "opus", effort: ""
        ))
        let back = try await turn(store, session)

        #expect(back.contains("said-to-codex"))
        #expect(!back.contains("said-to-claude"))
        try await acknowledge(store, session)
        #expect(try await turn(store, session) == "PROMPT")
    }

    @Test("thinking rows are left out of the read")
    func thinkingIsLeftOut() async throws {
        let store = try makeTestStore("handoff-thinking")
        let session = try await makeSession(store)
        try await say(store, session, "earlier words")
        let thought = #"{"type":"assistant","message":{"content":[{"type":"thinking","thinking":"private-thought"}]}}"#
        try await store.appendNext(sessionID: session.id, kind: .thinking, payload: Data(thought.utf8))

        #expect(try await store.handoffRows(sessionID: session.id, afterSeq: -1, excludingSeq: nil).map(\.kind) == [.user])
    }

    @Test("a worktree reads its branch and its changed files")
    func worktreeReadsBranchAndFiles() async throws {
        let path = TestScratch.unique("handoff-git")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q", "-b", "main"], cwd: path)
        try await Shell.check("git", ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "base"], cwd: path)
        try await Shell.check("git", ["checkout", "-q", "-b", "feature/x"], cwd: path)
        try "one\ntwo\n".write(toFile: path + "/new.txt", atomically: true, encoding: .utf8)

        let worktree = try #require(await HandoffWorktree.read(path: path, base: "main"))

        #expect(worktree.branch == "feature/x")
        #expect(worktree.files == ["new.txt (+2 -0)"])
    }

    @Test("a worktree git cannot read is no worktree at all")
    func unreadableWorktreeIsNil() async {
        #expect(await HandoffWorktree.read(path: TestScratch.unique("handoff-missing"), base: "main") == nil)
    }
}
