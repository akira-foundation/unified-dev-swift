import Testing
import Foundation
@testable import Core

@Suite("Handoff turn on Codex", .scratchDirectory)
struct HandoffTurnCodexTests: HandoffTurnRunnerFixture {
    @Test("Codex starts its turn with the delta and confirms on the first reply")
    func codexStartsWithTheDelta() async throws {
        let store = try makeTestStore("handoff-codex")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let delivery = try await claimed(store, session, "PROMPT")
        let box = codexBox()
        let runner = try await codexRunner(store, session, box)
        let before = try await cursor(store, session)

        try await runner.sendDelivery(delivery)

        let sent = try #require(codexText("turn/start", box))
        #expect(sent.contains("earlier words"))
        #expect(sent.hasSuffix("\n\nPROMPT"))
        #expect(try await storedUserTexts(store, session) == ["earlier words", "PROMPT"])
        #expect(try await cursor(store, session) == before)

        let promptSeq = try #require(try await store.delivery(id: delivery.id)?.deliveredSeq)
        emitCodexReply(box)
        await waitUntil("the first reply to be stored", within: .seconds(60)) {
            ((try? await store.messages(sessionID: session.id)) ?? []).contains { $0.kind == .assistantText }
        }
        await waitUntil("the first reply to confirm", within: .seconds(60)) {
            ((try? await store.activeSegment(sessionID: session.id))??.cursorSeq ?? -1) > promptSeq
        }
        await runner.shutdown()
    }

    @Test("Codex carries the cursor past the end of a turn that replied")
    func codexConfirmsOnTheEndOfTheTurn() async throws {
        let store = try makeTestStore("handoff-codex-end")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let delivery = try await claimed(store, session, "PROMPT")
        let box = codexBox()
        let runner = try await codexRunner(store, session, box)
        try await runner.sendDelivery(delivery)

        emitCodexReply(box)
        box.process.emit(#"{"method":"turn/completed","params":{"threadId":"\#(handoffThreadID)","turn":{"id":"\#(handoffTurnID)","status":"completed","items":[]}}}"#)

        await waitUntil("the end of the turn to confirm", within: .seconds(60)) {
            let rows = (try? await store.messages(sessionID: session.id)) ?? []
            let cursor = (try? await store.activeSegment(sessionID: session.id))??.cursorSeq
            return rows.last?.kind == .result && cursor == rows.last?.seq
        }
        await runner.shutdown()
    }

    @Test("a Codex error then a failed turn leave the cursor, and the next send carries the delta")
    func codexFailedTurnConfirmsNothing() async throws {
        let store = try makeTestStore("handoff-codex-failed")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let box = codexBox()
        let runner = try await codexRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        let before = try await cursor(store, session)

        box.process.emit(#"{"method":"error","params":{"threadId":"\#(handoffThreadID)","turnId":"\#(handoffTurnID)","error":{"message":"boom"},"willRetry":false}}"#)
        box.process.emit(#"{"method":"turn/completed","params":{"threadId":"\#(handoffThreadID)","turn":{"id":"\#(handoffTurnID)","status":"failed","error":{"message":"boom"},"items":[]}}}"#)
        await waitUntil("the failed turn to settle", within: .seconds(60)) {
            await runner.currentSession.state.isMidTurn == false
        }

        #expect(try await cursor(store, session) == before)

        let second = try await claimed(store, session, "AFTER")
        try await runner.sendDelivery(second)

        let starts = box.process.stdin.compactMap(JSONValue.parse).filter { $0["method"]?.stringValue == "turn/start" }
        #expect(starts.last?["params"]?["input"]?[0]?["text"]?.stringValue?.contains("earlier words") == true)
        await runner.shutdown()
    }

    @Test("a Codex turn interrupted before any reply leaves the cursor")
    func codexInterruptedBeforeAReplyConfirmsNothing() async throws {
        let store = try makeTestStore("handoff-codex-interrupted")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let box = codexBox()
        let runner = try await codexRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        let before = try await cursor(store, session)

        box.process.emit(#"{"method":"turn/completed","params":{"threadId":"\#(handoffThreadID)","turn":{"id":"\#(handoffTurnID)","status":"interrupted","items":[]}}}"#)
        await waitUntil("the interrupted turn to settle", within: .seconds(60)) {
            await runner.currentSession.state.isMidTurn == false
        }

        #expect(try await cursor(store, session) == before)
        await runner.shutdown()
    }

    @Test("a Codex steer sends the owner's words alone and confirms nothing")
    func codexSteerSendsOnlyTheWords() async throws {
        let store = try makeTestStore("handoff-codex-steer")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let box = codexBox()
        let runner = try await codexRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)
        let before = try await cursor(store, session)

        let second = try await claimed(store, session, "STEERED")
        try await runner.sendDelivery(second)

        #expect(codexText("turn/steer", box) == "STEERED")
        #expect(try await cursor(store, session) == before)
        await runner.shutdown()
    }

    @Test("a steer that misses its turn starts one that carries the delta")
    func codexMissedSteerCarriesTheDelta() async throws {
        let store = try makeTestStore("handoff-codex-missed")
        let session = try await enteredFromAnotherAgent(store, agent: .codex, model: "gpt-5")
        let box = codexBox()
        box.fail("turn/steer", code: -32000, message: "no active turn to steer")
        let runner = try await codexRunner(store, session, box)
        let first = try await claimed(store, session, "START")
        try await runner.sendDelivery(first)

        let second = try await claimed(store, session, "AFTER")
        try await runner.sendDelivery(second)

        let starts = box.process.stdin.compactMap(JSONValue.parse).filter { $0["method"]?.stringValue == "turn/start" }
        let sent = try #require(starts.last?["params"]?["input"]?[0]?["text"]?.stringValue)
        #expect(starts.count == 2)
        #expect(sent.contains("earlier words"))
        #expect(sent.hasSuffix("\n\nAFTER"))
        await runner.shutdown()
    }

    @Test("a handoff goes in front of a side conversation's context")
    func handoffGoesBeforeSideContext() async throws {
        let store = try makeTestStore("handoff-side")
        let parent = try await makeSession(store, agent: .codex, model: "gpt-5")
        let json = JSONValue.object(["type": .string("user"), "message": .object(["content": .string("parent words")])])
        try await store.appendNext(sessionID: parent.id, kind: .user, payload: Data(json.compactJSON.utf8))
        let child = try await store.openSideConversation(parentID: parent.id, streamingText: "")
        try await store.appendNext(sessionID: child.id, kind: .user, payload: Data(json.compactJSON.utf8))
        let entered = try await store.switchSegment(sessionID: child.id, to: SessionSegmentTarget(
            agentKind: .claudeCode, accountID: nil, model: "opus", effort: ""
        ))
        let switched = try await store.switchSegment(sessionID: entered.id, to: SessionSegmentTarget(
            agentKind: .codex, accountID: nil, model: "other", effort: ""
        ))
        let box = codexBox()
        let runner = try await codexRunner(store, switched, box)

        try await runner.send("Why?")

        let sent = try #require(codexText("turn/start", box))
        let record = try #require(sent.range(of: BridgeUntrustedText.opening))
        let side = try #require(sent.range(of: SideConversation.opening))
        let question = try #require(sent.range(of: "\n\nWhy?\n\n"))
        #expect(record.lowerBound < question.lowerBound)
        #expect(question.lowerBound < side.lowerBound)
        await runner.shutdown()
    }
}
