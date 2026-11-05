import Testing
import Foundation
@testable import Core

@Suite("Segment role", .tags(.persistence), .scratchDirectory)
struct SegmentRoleTests: HandoffTurnRunnerFixture {
    private func target(_ kind: AgentKind) -> SessionSegmentTarget {
        SessionSegmentTarget(agentKind: kind, accountID: nil, model: kind == .grok ? "grok-4.6" : "m", effort: "")
    }

    private func orchestrator(_ store: Store, start: AgentKind) async throws -> Session {
        let session = try await makeSession(store, agent: start, model: "first")
        try await store.setOrchestrator(true, workspaceID: try #require(session.workspaceID))
        return session
    }

    private func fingerprint(_ store: Store, _ id: SessionID) async throws -> AgentRunnerFingerprint {
        let seat = try #require(try await store.runnerSeat(sessionID: id))
        return AgentRunnerFingerprint(session: seat.session, account: nil, orchestrates: true, segment: seat.segmentID)
    }

    @Test("an orchestrator is built again on the new provider with the role it had")
    func orchestratorKeepsItsRoleOnEachProvider() async throws {
        let store = try makeTestStore("role-orchestrator")
        let session = try await orchestrator(store, start: .claudeCode)
        var seen = [try await fingerprint(store, session.id)]

        let codexSession = try await store.switchSegment(sessionID: session.id, to: target(.codex))
        seen.append(try await fingerprint(store, session.id))
        let codexProcess = codexBox()
        let runner = try await codexRunner(store, codexSession, codexProcess)
        try await runner.send("go")
        let thread = try #require(codexProcess.process.sentFrame { $0["method"]?.stringValue == "thread/start" })
        #expect(thread["params"]?["developerInstructions"]?.stringValue == OrchestratorRole.instructions)
        await runner.shutdown()

        let grokSession = try await store.switchSegment(sessionID: session.id, to: target(.grok))
        seen.append(try await fingerprint(store, session.id))
        let grokProcess = grokBox()
        let grok = try await grokRunner(store, grokSession, grokProcess)
        defer { grok.terminateNow() }
        try await grok.send("go")
        await waitUntil("the Grok prompt", within: .seconds(60)) { grokProcess.process.sentMethods.contains("session/prompt") }
        let prompt = try #require(grokProcess.process.sentFrame { $0["method"]?.stringValue == "session/prompt" })
        let text = prompt["params"]?["prompt"]?[0]?["text"]?.stringValue ?? ""
        #expect(text.contains(OrchestratorRole.instructions))
        let asked = try #require(grokProcess.process.sentFrame { $0["method"]?.stringValue == "session/new" })
        #expect(asked["params"]?["_meta"]?["yoloMode"]?.boolValue == false)

        let claudeSession = try await store.switchSegment(sessionID: session.id, to: target(.claudeCode))
        seen.append(try await fingerprint(store, session.id))
        let arguments = AgentRunner.argv(session: claudeSession, resume: nil, orchestrates: true)
        #expect(arguments.contains(OrchestratorRole.instructions))
        #expect(arguments.contains("--disallowedTools"))
        #expect(arguments.contains(OrchestratorToolGuard.claudeAskingMode))

        #expect(seen.count == 4)
        for index in seen.indices.dropFirst() { #expect(seen[index] != seen[index - 1]) }
        #expect(seen[3] != seen[0])
    }

    @Test("Ask keeps its instructions on every provider, Grok included")
    func askKeepsItsInstructionsOnGrok() async throws {
        let store = try makeTestStore("role-ask")
        let session = try await store.upsert(AskConversation.newSession())
        let grokSession = try await store.switchSegment(sessionID: session.id, to: target(.grok))
        let box = grokBox()
        let runner = try await grokRunner(store, grokSession, box)
        defer { runner.terminateNow() }

        try await runner.send("Open a workspace")
        await waitUntil("the Grok prompt", within: .seconds(60)) { box.process.sentMethods.contains("session/prompt") }

        let prompt = try #require(box.process.sentFrame { $0["method"]?.stringValue == "session/prompt" })
        let text = prompt["params"]?["prompt"]?[0]?["text"]?.stringValue ?? ""
        #expect(text.hasPrefix(AskConversation.instructions))
        #expect(text.hasSuffix("Open a workspace"))

        let codexSession = try await store.switchSegment(sessionID: session.id, to: target(.codex))
        let codexProcess = codexBox()
        let codex = try await codexRunner(store, codexSession, codexProcess)
        try await codex.send("Again")
        let thread = try #require(codexProcess.process.sentFrame { $0["method"]?.stringValue == "thread/start" })
        #expect(thread["params"]?["developerInstructions"]?.stringValue == AskConversation.instructions)
        await codex.shutdown()

        let claudeSession = try await store.switchSegment(sessionID: session.id, to: target(.claudeCode))
        #expect(AgentRunner.argv(session: claudeSession, resume: nil).contains(AskConversation.instructions))
    }

    @Test("a side conversation on Grok carries the parent's context into its first turn and says so")
    func sideConversationCarriesContextOnGrok() async throws {
        let store = try makeTestStore("role-side-grok")
        let parent = try await makeSession(store, agent: .grok, model: "grok-4.6")
        let child = try await store.openSideConversation(parentID: parent.id, streamingText: "Original context")
        let box = grokBox()
        let runner = try await grokRunner(store, child, box)
        defer { runner.terminateNow() }
        #expect(try await store.setting(SideConversation.contextDeliveredKey(child.id)) == nil)

        try await runner.send("Why?")
        await waitUntil("the Grok prompt", within: .seconds(60)) { box.process.sentMethods.contains("session/prompt") }

        let prompt = try #require(box.process.sentFrame { $0["method"]?.stringValue == "session/prompt" })
        let text = prompt["params"]?["prompt"]?[0]?["text"]?.stringValue ?? ""
        #expect(text.contains("Original context"))
        #expect(text.contains("Why?"))
        #expect(try await store.setting(SideConversation.contextDeliveredKey(child.id)) == "1")
        #expect(try await storedUserTexts(store, child) == ["Why?"])
    }

    @Test("switching a parent leaves its side conversation on its own provider and session")
    func switchingAParentLeavesItsChildrenAlone() async throws {
        let store = try makeTestStore("role-children")
        let parent = try await makeSession(store, agent: .codex, model: "gpt-5")
        let opened = try await store.openSideConversation(parentID: parent.id)
        let child = try #require(try await store.update(sessionID: opened.id) { $0.agentSessionID = "child-thread" })
        let childSegments = try await store.segments(sessionID: child.id)

        _ = try await store.switchSegment(sessionID: parent.id, to: target(.grok))
        let switched = try await store.switchSegment(sessionID: parent.id, to: target(.claudeCode))
        #expect(switched.agentKind == .claudeCode)
        #expect(try await store.session(id: parent.id)?.agentKind == .claudeCode)

        let after = try #require(try await store.session(id: child.id))
        #expect(after.agentKind == .codex)
        #expect(after.agentSessionID == "child-thread")
        #expect(after.sideConversationParentID == parent.id)
        #expect(try await store.segments(sessionID: child.id) == childSegments)
        #expect(try await store.messages(sessionID: child.id).isEmpty)
    }
}
