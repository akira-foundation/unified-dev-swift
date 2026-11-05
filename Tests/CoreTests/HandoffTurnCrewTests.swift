import Testing
import Foundation
@testable import Core

@Suite("Handoff turn with crew messages", .tags(.persistence), .scratchDirectory)
struct HandoffTurnCrewTests {
    private func makeSession(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "feature/w",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    private func crewPayload(_ text: String = "the report") throws -> Data {
        try CrewMessage(event: .said, sender: .subagent, from: "worker", text: text, sent: text).payload()
    }

    private func reply(_ seq: Int, _ text: String, chat: SessionID) -> Message {
        let json = #"{"type":"assistant","message":{"model":"opus","content":[{"type":"text","text":"\#(text)"}]}}"#
        return Message(sessionID: chat, seq: seq, kind: .assistantText, payload: Data(json.utf8))
    }

    @Test("a crew row alone after the cursor makes a delta due, with its sender and text")
    func aCrewRowAloneIsADelta() async throws {
        let store = try makeTestStore("handoff-crew-alone")
        let session = try await makeSession(store)
        try await store.appendNext(sessionID: session.id, kind: .crew, payload: try crewPayload())

        let due = try await store.handoffIsDue(sessionID: session.id, deliveredSeq: nil)
        let prompt = try await store.handoffTurn(
            "PROMPT", sessionID: session.id, deliveredSeq: nil, worktree: nil, contextWindow: nil
        )

        #expect(due)
        #expect(prompt.contains("worker"))
        #expect(prompt.contains("the report"))
    }

    @Test("a crew row that does not decode is skipped and opens no turn")
    func anUndecodableCrewRowIsSkipped() throws {
        let chat = SessionID("chat")
        let owner = #"{"type":"user","message":{"content":"owner words"}}"#
        let rows = [
            Message(sessionID: chat, seq: 0, kind: .user, payload: Data(owner.utf8)),
            reply(1, "first answer", chat: chat),
            Message(sessionID: chat, seq: 2, kind: .result, payload: Data(#"{"subtype":"success","is_error":false}"#.utf8)),
            Message(sessionID: chat, seq: 3, kind: .crew, payload: Data("{}".utf8)),
        ]

        let text = try #require(ConversationHandoff.text(
            messages: rows, worktree: nil, chatID: chat, budget: 100_000, agent: .codex
        ))

        #expect(text.contains("Conversation record: 1 turn"))
        #expect(!text.contains("interrupted"))
        #expect(ConversationHandoff.text(
            messages: [rows[3]], worktree: nil, chatID: chat, budget: 100_000, agent: .codex
        ) == nil)
    }

    @Test("a reply to a crew message sits under it, in its own turn")
    func aReplySitsUnderItsCrewMessage() throws {
        let chat = SessionID("chat")
        let owner = #"{"type":"user","message":{"content":"owner words"}}"#
        let rows = [
            Message(sessionID: chat, seq: 0, kind: .user, payload: Data(owner.utf8)),
            reply(1, "first answer", chat: chat),
            Message(sessionID: chat, seq: 2, kind: .result, payload: Data(#"{"subtype":"success","is_error":false}"#.utf8)),
            Message(sessionID: chat, seq: 3, kind: .crew, payload: try crewPayload()),
            reply(4, "answer to the worker", chat: chat),
            Message(sessionID: chat, seq: 5, kind: .result, payload: Data(#"{"subtype":"success","is_error":false}"#.utf8)),
        ]

        let text = try #require(ConversationHandoff.text(
            messages: rows, worktree: nil, chatID: chat, budget: 100_000, agent: .codex
        ))

        let sender = try #require(text.range(of: "the report"))
        let answer = try #require(text.range(of: "answer to the worker"))
        let first = try #require(text.range(of: "first answer"))
        #expect(text.contains("Conversation record: 2 turns"))
        #expect(first.lowerBound < sender.lowerBound)
        #expect(sender.lowerBound < answer.lowerBound)
    }
}
