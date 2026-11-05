import Testing
import Foundation
@testable import Core

@Suite("A forked chat keeps its source", .scratchDirectory)
struct ForkSourceTests {
    private let claude = SessionSegmentTarget(agentKind: .claudeCode, accountID: nil, model: "opus", effort: "")
    private let grok = SessionSegmentTarget(agentKind: .grok, accountID: nil, model: "grok-4", effort: "")

    private func makeChat(_ store: Store, agent: AgentKind) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("tree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, model: "m", agentKind: agent))
    }

    @discardableResult
    private func say(_ store: Store, _ session: Session, _ text: String) async throws -> Int {
        let line = JSONValue.object(["type": .string("user"), "message": .object(["content": .string(text)])])
        return try await store.appendNext(
            sessionID: session.id, kind: .user, payload: Data(line.compactJSON.utf8)
        ).seq
    }

    private func reply(_ store: Store, _ session: Session, _ text: String) async throws {
        let line = #"{"type":"assistant","message":{"model":"m","content":[{"type":"text","text":"\#(text)"}]}}"#
        try await store.appendNext(sessionID: session.id, kind: .assistantText, payload: Data(line.utf8))
    }

    private func delivered(_ store: Store, _ session: Session) async throws {
        let active = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.acknowledgeHandoff(sessionID: session.id, fromSegment: active.id, carriedDelta: true)
    }

    private func nextPrompt(_ store: Store, _ session: Session) async throws -> String {
        try await store.handoffTurn("next", sessionID: session.id, deliveredSeq: nil, worktree: nil, contextWindow: nil)
    }

    private func forkFromCodexToClaude(_ store: Store) async throws -> (origin: Session, fork: Session) {
        let origin = try await makeChat(store, agent: .codex)
        try await say(store, origin, "words of the origin")
        try await reply(store, origin, "origin answered")
        let fork = try await makeChat(store, agent: .claudeCode)
        try await store.seed(sessionID: fork.id, from: origin.id)
        try await say(store, fork, "first words on claude")
        return (origin, fork)
    }

    private func answeredOnClaude(_ store: Store) async throws -> (origin: Session, fork: Session) {
        let chats = try await forkFromCodexToClaude(store)
        #expect(try await nextPrompt(store, chats.fork).contains("words of the origin"))
        try await reply(store, chats.fork, "claude answered")
        try await delivered(store, chats.fork)
        try await store.update(sessionID: chats.fork.id) { $0.agentSessionID = "claude-native" }
        return chats
    }

    @Test("a third agent still learns the origin after the first one received it")
    func aThirdAgentLearnsTheOrigin() async throws {
        let store = try makeTestStore("fork-third")
        let chats = try await answeredOnClaude(store)
        #expect(try await nextPrompt(store, chats.fork) == "next")

        _ = try await store.switchSegment(sessionID: chats.fork.id, to: grok)

        let prompt = try await nextPrompt(store, chats.fork)
        #expect(prompt.contains("words of the origin"))
        #expect(prompt.contains("claude answered"))
    }

    @Test("going back to a segment that received the origin does not repeat it")
    func aReturnDoesNotRepeatTheOrigin() async throws {
        let store = try makeTestStore("fork-return")
        let chats = try await answeredOnClaude(store)
        _ = try await store.switchSegment(sessionID: chats.fork.id, to: grok)
        try await say(store, chats.fork, "a word to grok")
        _ = try await nextPrompt(store, chats.fork)
        try await delivered(store, chats.fork)
        try await store.update(sessionID: chats.fork.id) { $0.agentSessionID = "grok-native" }
        _ = try await store.switchSegment(sessionID: chats.fork.id, to: claude)

        let prompt = try await nextPrompt(store, chats.fork)

        #expect(!prompt.contains("words of the origin"))
        #expect(prompt.contains("a word to grok"))
    }

    @Test("a source deleted after the fork breaks nothing")
    func aDeletedSourceBreaksNothing() async throws {
        let store = try makeTestStore("fork-deleted")
        let chats = try await forkFromCodexToClaude(store)

        try await store.deleteSession(id: chats.origin.id)

        #expect(try await store.pendingSource(sessionID: chats.fork.id) == nil)
        let prompt = try await nextPrompt(store, chats.fork)
        #expect(prompt.hasSuffix("next"))
        #expect(!prompt.contains("words of the origin"))
    }

    @Test("a source that is only missing its row is read as nothing")
    func aSourceDeletedAfterTheSecondSegmentBreaksNothing() async throws {
        let store = try makeTestStore("fork-deleted-late")
        let chats = try await answeredOnClaude(store)
        _ = try await store.switchSegment(sessionID: chats.fork.id, to: grok)

        try await store.deleteSession(id: chats.origin.id)

        let prompt = try await nextPrompt(store, chats.fork)
        #expect(prompt.contains("claude answered"))
        #expect(!prompt.contains("words of the origin"))
    }

    @Test("a turn that carried no delta does not count as having received the origin")
    func aPromptWithoutADeltaLeavesTheOriginOwed() async throws {
        let store = try makeTestStore("fork-no-delta")
        let chats = try await forkFromCodexToClaude(store)
        let active = try #require(try await store.activeSegment(sessionID: chats.fork.id))

        try await store.acknowledgeHandoff(sessionID: chats.fork.id, fromSegment: active.id, carriedDelta: false)

        #expect(try await store.pendingSource(sessionID: chats.fork.id) == chats.origin.id)
        #expect(try await nextPrompt(store, chats.fork).contains("words of the origin"))
    }

    @Test("a native session lost after receiving the origin is told it again")
    func aLostHistoryIsToldTheOriginAgain() async throws {
        let store = try makeTestStore("fork-lost")
        let chats = try await answeredOnClaude(store)
        let active = try #require(try await store.activeSegment(sessionID: chats.fork.id))

        try await store.resetCursor(segmentID: active.id)

        #expect(try await nextPrompt(store, chats.fork).contains("words of the origin"))
    }

    private func clean(_ store: Store, _ session: Session) async throws {
        let line = #"{"type":"result","subtype":"success","is_error":false,"result":"done"}"#
        try await store.appendNext(sessionID: session.id, kind: .result, payload: Data(line.utf8))
    }

    @Test("what the source says after the fork stays out of the delta")
    func theSourceIsReadOnlyUpToTheFork() async throws {
        let store = try makeTestStore("fork-ceiling")
        let chats = try await forkFromCodexToClaude(store)

        try await say(store, chats.origin, "said after the fork")
        try await reply(store, chats.origin, "answered after the fork")

        let prompt = try await nextPrompt(store, chats.fork)
        #expect(prompt.contains("words of the origin"))
        #expect(!prompt.contains("said after the fork"))
        #expect(!prompt.contains("answered after the fork"))
    }

    @Test("a turn running on the source after the fork does not read as interrupted")
    func aLiveTurnOnTheSourceIsNotInterrupted() async throws {
        let store = try makeTestStore("fork-live")
        let origin = try await makeChat(store, agent: .codex)
        try await say(store, origin, "words of the origin")
        try await reply(store, origin, "origin answered")
        try await clean(store, origin)
        let fork = try await makeChat(store, agent: .claudeCode)
        try await store.seed(sessionID: fork.id, from: origin.id)

        try await say(store, origin, "a new turn is running")

        #expect(!(try await nextPrompt(store, fork)).contains("interrupted"))
    }

    @Test("a later agent reads the source up to the same place")
    func aLaterAgentStopsAtTheSamePlace() async throws {
        let store = try makeTestStore("fork-ceiling-later")
        let chats = try await answeredOnClaude(store)
        try await say(store, chats.origin, "said after the fork")
        _ = try await store.switchSegment(sessionID: chats.fork.id, to: grok)

        let prompt = try await nextPrompt(store, chats.fork)

        #expect(prompt.contains("words of the origin"))
        #expect(!prompt.contains("said after the fork"))
    }

    @Test("a source with nothing said yet tells nothing, whatever it says later")
    func anEmptySourceStaysEmpty() async throws {
        let store = try makeTestStore("fork-empty")
        let origin = try await makeChat(store, agent: .codex)
        let fork = try await makeChat(store, agent: .claudeCode)
        try await store.seed(sessionID: fork.id, from: origin.id)

        try await say(store, origin, "said after the fork")

        #expect(try await nextPrompt(store, fork) == "next")
    }

    @Test("a fork of a fork carries its own source and not that source's source")
    func aForkOfAForkStopsAtItsOwnSource() async throws {
        let store = try makeTestStore("fork-of-fork")
        let chats = try await answeredOnClaude(store)
        let second = try await makeChat(store, agent: .grok)
        try await store.seed(sessionID: second.id, from: chats.fork.id)

        let prompt = try await nextPrompt(store, second)

        #expect(prompt.contains("first words on claude"))
        #expect(!prompt.contains("words of the origin"))
    }

    @Test("a chat that was never forked owes nothing and names no source")
    func aChatNeverForkedOwesNothing() async throws {
        let store = try makeTestStore("fork-none")
        let chat = try await makeChat(store, agent: .codex)

        #expect(try await store.pendingSource(sessionID: chat.id) == nil)
        #expect(try await store.handoffIsDue(sessionID: chat.id, deliveredSeq: nil) == false)
    }
}
