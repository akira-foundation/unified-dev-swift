import Testing
import Foundation
@testable import Core

@Suite("Handoff turn on Claude", .scratchDirectory)
struct HandoffTurnClaudeTests: HandoffTurnRunnerFixture {
    @Test("Claude is sent the delta while the row keeps the owner's words")
    func claudeSendsTheDeltaAndStoresTheOriginal() async throws {
        let store = try makeTestStore("handoff-claude")
        let session = try await enteredFromAnotherAgent(store, agent: .claudeCode, model: "opus")
        let delivery = try await claimed(store, session, "PROMPT")
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)
        let before = try await cursor(store, session)

        try await runner.sendDelivery(delivery)

        let line = try #require(box.process.stdin.last)
        #expect(line.contains("earlier words"))
        #expect(line.components(separatedBy: "PROMPT").count == 2)
        #expect(try await storedUserTexts(store, session) == ["earlier words", "PROMPT"])
        #expect(try await cursor(store, session) == before)
        runner.terminateNow()
    }

    @Test("Claude confirms on the first reply, and on the end of the turn")
    func claudeConfirmsOnReplyAndResult() async throws {
        let store = try makeTestStore("handoff-claude-ack")
        let session = try await enteredFromAnotherAgent(store, agent: .claudeCode, model: "opus")
        let delivery = try await claimed(store, session, "PROMPT")
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)
        try await runner.sendDelivery(delivery)

        await runner.ingest(claudeReply("working"))
        let afterReply = try await store.nextSeq(sessionID: session.id) - 1
        #expect(try await cursor(store, session) == afterReply)

        await runner.ingest(claudeReply("more"))
        #expect(try await cursor(store, session) == afterReply)

        await runner.ingest(claudeResult)
        #expect(try await cursor(store, session) == store.nextSeq(sessionID: session.id) - 1)
        runner.terminateNow()
    }

    @Test("a Claude message sent mid-turn carries none of the agent's own rows")
    func claudeMidTurnCarriesNoOwnRows() async throws {
        let store = try makeTestStore("handoff-claude-midturn")
        let session = try await makeSession(store, agent: .claudeCode, model: "opus")
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        await runner.ingest(claudeReply("first-reply"))
        await runner.ingest(claudeReply("own-later-row"))

        let second = try await claimed(store, session, "MIDTURN")
        try await runner.sendDelivery(second)

        #expect(box.process.stdin.last?.contains("own-later-row") == false)
        runner.terminateNow()
    }

    @Test("the limit line and a failed result leave the cursor, and the next send carries the delta")
    func claudeLimitLineConfirmsNothing() async throws {
        let store = try makeTestStore("handoff-claude-limit")
        let session = try await enteredFromAnotherAgent(store, agent: .claudeCode, model: "opus")
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        let before = try await cursor(store, session)

        let line = try fixtureLines("claude-usage-limit.ndjson")[0]
        await runner.ingest(try #require(AgentEvent.decode(line: line)))
        let failed = #"{"type":"result","subtype":"success","is_error":true,"result":"limit","session_id":"s"}"#
        await runner.ingest(try #require(AgentEvent.decode(line: failed)))

        #expect(try await cursor(store, session) == before)

        let second = try await claimed(store, session, "AFTER")
        try await runner.sendDelivery(second)

        #expect(box.process.stdin.last?.contains("earlier words") == true)
        runner.terminateNow()
    }

    @Test("a Claude message sent mid-turn does not repeat a delta the turn already carried")
    func claudeMidTurnDoesNotRepeatTheDelta() async throws {
        let store = try makeTestStore("handoff-claude-midturn-delta")
        let session = try await enteredFromAnotherAgent(store, agent: .claudeCode, model: "opus")
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        #expect(box.process.stdin.last?.contains("earlier words") == true)

        let second = try await claimed(store, session, "MIDTURN")
        try await runner.sendDelivery(second)

        #expect(box.process.stdin.last?.contains("earlier words") == false)
        runner.terminateNow()
    }

    @Test("a Claude turn stopped after its reply does not reread its own rows")
    func claudeStoppedTurnDoesNotRereadItself() async throws {
        let store = try makeTestStore("handoff-claude-stop")
        let session = try await makeSession(store, agent: .claudeCode, model: "opus")
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        await runner.ingest(claudeReply("first-reply"))
        await runner.ingest(claudeReply("own-later-row"))
        runner.cancelNow()
        await waitUntil("the stop to settle", within: .seconds(2)) {
            await runner.currentSession.state.isMidTurn == false
        }

        let second = try await claimed(store, session, "NEXT")
        try await runner.sendDelivery(second)

        #expect(box.process.stdin.last?.contains("own-later-row") == false)
        runner.terminateNow()
    }

    @Test("a stale delivery value still leaves its own prompt out of the delta")
    func staleDeliveryValueLeavesThePromptOut() async throws {
        let store = try makeTestStore("handoff-stale")
        let session = try await enteredFromAnotherAgent(store, agent: .claudeCode, model: "opus")
        let delivery = try await claimed(store, session, "PROMPT")
        #expect(delivery.deliveredSeq == nil)
        let box = ProcessBox()
        let runner = claudeRunner(store, session, box)

        try await runner.sendDelivery(delivery)

        #expect(try #require(box.process.stdin.last).components(separatedBy: "PROMPT").count == 2)
        runner.terminateNow()
    }
}
