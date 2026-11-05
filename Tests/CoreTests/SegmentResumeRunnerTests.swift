import Testing
import Foundation
@testable import Core

@Suite("A runner that cannot resume its native session", .scratchDirectory)
struct SegmentResumeRunnerTests: HandoffTurnRunnerFixture {
    private func claudeInit(_ id: String) -> AgentEvent {
        AgentEvent.decode(line: #"{"type":"system","subtype":"init","session_id":"\#(id)"}"#) ?? .unknown(Data())
    }

    private let refusedResult = AgentEvent.decode(
        line: #"{"type":"result","subtype":"error_during_execution","is_error":true,"session_id":"asked-for"}"#
    ) ?? .unknown(Data())

    private func spokenChat(
        _ store: Store, agent: AgentKind, model: String, native: String?
    ) async throws -> (Session, Delivery) {
        let session = try await makeSession(store, agent: agent, model: model)
        let json = JSONValue.object(["type": .string("user"), "message": .object(["content": .string("the-oldest-words")])])
        try await store.appendNext(sessionID: session.id, kind: .user, payload: Data(json.compactJSON.utf8))
        let active = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.acknowledgeHandoff(sessionID: session.id, fromSegment: active.id)
        let stored = try #require(try await store.update(sessionID: session.id) { $0.agentSessionID = native })
        return (stored, try await claimed(store, stored, "PROMPT"))
    }

    private func unspokenChat(_ store: Store, native: String) async throws -> (Session, Delivery) {
        let session = try await makeSession(store, agent: .claudeCode, model: "opus")
        let stored = try #require(try await store.update(sessionID: session.id) { $0.agentSessionID = native })
        let active = try #require(try await store.activeSegment(sessionID: session.id))
        try await store.resetCursor(segmentID: active.id)
        return (stored, try await store.enqueueDelivery(Delivery(targetSessionID: session.id, body: "UNCLAIMED")))
    }

    @Test("Claude answering with another session resets the cursor, and the next send carries everything")
    func claudeAnotherSessionResets() async throws {
        let store = try makeTestStore("resume-claude-lost")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let box = ProcessBox()
        let runner = try await claudeRunner(store, session, box)
        try await runner.sendDelivery(delivery)
        #expect(box.process.stdin.last?.contains("the-oldest-words") == false)

        await runner.ingest(claudeInit("another"))

        #expect(try await cursor(store, session) == -1)
        #expect(try await store.session(id: session.id)?.agentSessionID == "another")
        runner.terminateNow()
    }

    @Test("a turn already under way cannot undo the reset, whatever the phase it found")
    func aResetIsNotUndoneByASettledPhase() async throws {
        let store = try makeTestStore("resume-claude-settled")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let box = ProcessBox()
        let runner = try await claudeRunner(store, session, box)
        try await runner.sendDelivery(delivery)
        await runner.ingest(claudeInit("another"))

        await runner.ingest(claudeReply("first reply"))
        await runner.ingest(claudeResult)
        #expect(try await cursor(store, session) == -1)

        let next = try await claimed(store, session, "NEXT")
        try await runner.sendDelivery(next)

        let line = try #require(box.process.stdin.last)
        #expect(line.contains("the-oldest-words"))
        #expect(line.contains("first reply"))
        #expect(line.contains("NEXT"))
        runner.terminateNow()
    }

    @Test("a refusal landing before a prompt that owed no delta still holds the cursor back")
    func aRefusalBeforeAnEmptyPromptIsNotConfirmedAway() async throws {
        let store = try makeTestStore("resume-claude-empty")
        let (session, delivery) = try await unspokenChat(store, native: "asked-for")
        let box = ProcessBox()
        let runner = try await claudeRunner(store, session, box)
        await #expect(throws: DeliveryDispatchError.self) { try await runner.sendDelivery(delivery) }
        await runner.ingest(refusedResult)
        #expect(try await cursor(store, session) == -1)

        try await runner.send("FIRST")
        #expect(box.process.stdin.last?.contains("FIRST") == true)
        await runner.ingest(claudeReply("first reply"))
        await runner.ingest(claudeResult)
        #expect(try await cursor(store, session) == -1)

        try await runner.send("NEXT")

        let line = try #require(box.process.stdin.last)
        #expect(line.contains("first reply"))
        #expect(line.contains("NEXT"))
        runner.terminateNow()
    }

    @Test("Claude resuming the session it asked for leaves the cursor")
    func claudeSameSessionKeepsTheCursor() async throws {
        let store = try makeTestStore("resume-claude-same")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let runner = try await claudeRunner(store, session, ProcessBox())
        try await runner.sendDelivery(delivery)
        let before = try await cursor(store, session)

        await runner.ingest(claudeInit("asked-for"))

        #expect(try await cursor(store, session) == before)
        runner.terminateNow()
    }

    @Test("a brand new Claude session getting its first id leaves the cursor")
    func claudeFirstIDKeepsTheCursor() async throws {
        let store = try makeTestStore("resume-claude-first")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: nil)
        let runner = try await claudeRunner(store, session, ProcessBox())
        try await runner.sendDelivery(delivery)
        let before = try await cursor(store, session)

        await runner.ingest(claudeInit("first"))

        #expect(try await cursor(store, session) == before)
        #expect(try await store.session(id: session.id)?.agentSessionID == "first")
        runner.terminateNow()
    }

    @Test("a later init in the same process is not a lost history")
    func claudeSecondInitKeepsTheCursor() async throws {
        let store = try makeTestStore("resume-claude-second")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let runner = try await claudeRunner(store, session, ProcessBox())
        try await runner.sendDelivery(delivery)
        await runner.ingest(claudeInit("asked-for"))
        let before = try await cursor(store, session)

        await runner.ingest(claudeInit("changed-mid-process"))

        #expect(try await cursor(store, session) == before)
        runner.terminateNow()
    }

    @Test("Claude refusing the resume clears the id and resets, so the next process starts fresh with everything")
    func claudeRefusedResume() async throws {
        let store = try makeTestStore("resume-claude-refused")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let box = ProcessBox()
        let runner = try await claudeRunner(store, session, box)
        try await runner.sendDelivery(delivery)
        #expect(box.process.launch.arguments.contains("asked-for"))

        await runner.ingest(refusedResult)

        #expect(try await cursor(store, session) == -1)
        #expect(try await store.session(id: session.id)?.agentSessionID == nil)
        #expect(await runner.launch().arguments.contains("--resume") == false)
        runner.terminateNow()
    }

    @Test("a Stop before the init ends in the same shape and keeps the session")
    func claudeStopBeforeInitKeepsTheSession() async throws {
        let store = try makeTestStore("resume-claude-stopped")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let runner = try await claudeRunner(store, session, ProcessBox())
        try await runner.sendDelivery(delivery)

        await runner.cancel()
        await runner.ingest(refusedResult)

        #expect(try await cursor(store, session) != -1)
        #expect(await runner.currentSession.agentSessionID == "asked-for")
        runner.terminateNow()
    }

    @Test("a failing turn after the init does not throw the session away")
    func claudeErrorAfterInitKeepsTheSession() async throws {
        let store = try makeTestStore("resume-claude-error")
        let (session, delivery) = try await spokenChat(store, agent: .claudeCode, model: "opus", native: "asked-for")
        let runner = try await claudeRunner(store, session, ProcessBox())
        try await runner.sendDelivery(delivery)
        await runner.ingest(claudeInit("asked-for"))

        await runner.ingest(refusedResult)

        #expect(try await cursor(store, session) != -1)
        #expect(try await store.session(id: session.id)?.agentSessionID == "asked-for")
        runner.terminateNow()
    }

    @Test("Codex opens a new thread when the resume fails, and that same send carries everything")
    func codexResumeFails() async throws {
        let store = try makeTestStore("resume-codex-fails")
        let (session, delivery) = try await spokenChat(store, agent: .codex, model: "gpt-5", native: "gone")
        let box = codexBox()
        box.fail("thread/resume", code: -32600, message: "no rollout found")
        let runner = try await codexRunner(store, session, box)

        try await runner.sendDelivery(delivery)

        #expect(box.process.sentMethods.contains("thread/start"))
        let sent = try #require(codexText("turn/start", box))
        #expect(sent.contains("the-oldest-words"))
        #expect(sent.hasSuffix("\n\nPROMPT"))
        #expect(try await store.session(id: session.id)?.agentSessionID == handoffThreadID)
        await runner.shutdown()
    }

    @Test("Codex resuming its thread leaves the cursor and carries nothing")
    func codexResumeWorks() async throws {
        let store = try makeTestStore("resume-codex-works")
        let (session, delivery) = try await spokenChat(store, agent: .codex, model: "gpt-5", native: handoffThreadID)
        let box = codexBox()
        box.reply(to: "thread/resume", with: .object([
            "thread": .object(["id": .string(handoffThreadID)]), "model": .string("gpt-5"),
        ]))
        let runner = try await codexRunner(store, session, box)
        let before = try await cursor(store, session)

        try await runner.sendDelivery(delivery)

        #expect(codexText("turn/start", box) == "PROMPT")
        #expect(try await cursor(store, session) == before)
        await runner.shutdown()
    }

    @Test("Codex with a dead server changes nothing, so the next attempt can still resume")
    func codexNewThreadFailsToo() async throws {
        let store = try makeTestStore("resume-codex-dead")
        let (session, delivery) = try await spokenChat(store, agent: .codex, model: "gpt-5", native: "kept")
        let box = codexBox()
        box.fail("thread/resume", code: -32600, message: "no")
        box.fail("thread/start", code: -32600, message: "no")
        let runner = try await codexRunner(store, session, box)
        let before = try await cursor(store, session)

        await #expect(throws: (any Error).self) { try await runner.sendDelivery(delivery) }

        #expect(try await cursor(store, session) == before)
        #expect(try await store.session(id: session.id)?.agentSessionID == "kept")
        await runner.shutdown()
    }

    @Test("Grok opens a new session when the resume fails, and that same send carries everything")
    func grokResumeFails() async throws {
        let store = try makeTestStore("resume-grok-fails")
        let (session, delivery) = try await spokenChat(store, agent: .grok, model: "grok-4.6", native: "gone")
        let box = grokBox()
        box.fail("session/resume", code: -32600, message: "no session")
        let runner = try await grokRunner(store, session, box)
        defer { runner.terminateNow() }

        try await runner.sendDelivery(delivery)

        let frame = try #require(box.process.sentFrame { $0["method"]?.stringValue == "session/prompt" })
        let spoken = try #require(frame["params"]?["prompt"]?[0]?["text"]?.stringValue)
        #expect(spoken.contains("the-oldest-words"))
        #expect(spoken.hasSuffix("\n\nPROMPT"))
        #expect(try await store.session(id: session.id)?.agentSessionID == "sess-1")
    }

    @Test("Grok resuming its session leaves the cursor and carries nothing")
    func grokResumeWorks() async throws {
        let store = try makeTestStore("resume-grok-works")
        let (session, delivery) = try await spokenChat(store, agent: .grok, model: "grok-4.6", native: "sess-1")
        let box = grokBox()
        box.reply(to: "session/resume", with: .object(["sessionId": .string("sess-1")]))
        let runner = try await grokRunner(store, session, box)
        defer { runner.terminateNow() }
        let before = try await cursor(store, session)

        try await runner.sendDelivery(delivery)

        let frame = try #require(box.process.sentFrame { $0["method"]?.stringValue == "session/prompt" })
        #expect(frame["params"]?["prompt"]?[0]?["text"]?.stringValue?.contains("the-oldest-words") == false)
        #expect(try await cursor(store, session) == before)
    }
}
