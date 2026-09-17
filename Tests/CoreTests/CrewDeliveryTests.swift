import Foundation
import Testing
@testable import Core

@Suite("A crew message on its way to an agent", .tags(.persistence), .scratchDirectory)
struct CrewDeliveryTests {
    private func makeMember(_ store: Store) async throws -> (Workspace, Session) {
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id,
            name: "crew",
            branch: "unifieddev/crew",
            path: TestScratch.unique("worktree"),
            baseBranch: "main"
        ))
        let parent = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        let member = try await store.upsert(Session(
            workspaceID: workspace.id, parentSessionID: parent.id, title: "reader"
        ))
        return (workspace, member)
    }

    @Test("a delivery holds the words a person reads and the envelope the model is handed")
    func carriesBothRenderings() throws {
        let message = CrewMessage.said(from: "reader", text: "All 18 tests pass.", sender: .subagent)
        let delivery = Delivery(targetSessionID: SessionID("s"), kind: .message, crew: message)

        #expect(delivery.body == "All 18 tests pass.")
        #expect(delivery.sent == message.sent)
        #expect(delivery.sent.contains(BridgeUntrustedText.opening))
        #expect(!delivery.body.contains(BridgeUntrustedText.opening))
        #expect(delivery.crewMessage == message)
    }

    @Test("a message the owner typed carries no crew payload and is sent as it stands")
    func ownerMessagesAreUnchanged() {
        let delivery = Delivery(targetSessionID: SessionID("s"), body: "list the technologies used")

        #expect(delivery.crewPayload == nil)
        #expect(delivery.crewMessage == nil)
        #expect(delivery.sent == "list the technologies used")
    }

    @Test("a brief is carried as a crew message even though it is not wrapped")
    func briefTravelsAsCrew() throws {
        let brief = CrewMessage.brief(from: "Chat", task: "Read the cascade and report.")
        let delivery = Delivery(targetSessionID: SessionID("s"), kind: .message, crew: brief)

        #expect(delivery.body == "Read the cascade and report.")
        #expect(delivery.sent == "Read the cascade and report.")
        #expect(delivery.crewMessage?.event == .brief)
    }

    @Test("both renderings survive the queue")
    func survivesTheTable() async throws {
        let store = try makeTestStore("crew-delivery")
        let (workspace, member) = try await makeMember(store)
        let message = CrewMessage.stopped(name: "reader", lastMessage: "All 18 tests pass.")

        let written = try await store.enqueueDelivery(Delivery(
            targetSessionID: member.id,
            sourceWorkspaceID: workspace.id,
            kind: .report,
            crew: message
        ))

        let pending = try await store.pendingDeliveries(sessionID: member.id)
        #expect(pending.count == 1)
        let read = try #require(pending.first)
        #expect(read.id == written.id)
        #expect(read.kind == .report)
        #expect(read.crewPayload == written.crewPayload)
        #expect(read.crewMessage == message)
        #expect(read.body == message.text)
        #expect(read.sent == message.sent)
    }

    @Test("a message the owner typed reads back with the column empty")
    func ownerRowsStayEmpty() async throws {
        let store = try makeTestStore("crew-delivery-owner")
        let (_, member) = try await makeMember(store)
        try await store.enqueueDelivery(Delivery(targetSessionID: member.id, body: "carry on"))

        let read = try #require(try await store.pendingDeliveries(sessionID: member.id).first)
        #expect(read.crewPayload == nil)
        #expect(read.sent == "carry on")
    }

    @Test("the column's migration replays over a database that already has it")
    func migrationReplays() async throws {
        let path = TestScratch.unique("crew-delivery-migration") + ".sqlite"
        let store = try Store(path: path)
        let (workspace, member) = try await makeMember(store)
        let message = CrewMessage.said(from: "Chat", text: "Carry on.", sender: .orchestrator)
        let crew = try await store.enqueueDelivery(Delivery(
            targetSessionID: member.id,
            sourceWorkspaceID: workspace.id,
            kind: .message,
            crew: message
        ))
        let typed = try await store.enqueueDelivery(
            Delivery(targetSessionID: member.id, body: "and then stop")
        )

        let raw = try SQLiteDatabase(path: path)
        try raw.setUserVersion(0)

        let reopened = try Store(path: path)
        let pending = try await reopened.pendingDeliveries(sessionID: member.id)
        #expect(pending.map(\.id) == [crew.id, typed.id])
        #expect(pending.first?.crewMessage == message)
        #expect(pending.last?.crewPayload == nil)
    }

    @Test("the drain hands the model the envelope and the runner the row to write down")
    func drainSeparatesTheTwoHalves() async throws {
        let runner = RecordingRunner()
        let message = CrewMessage.said(from: "reader", text: "Done.", sender: .subagent)
        let delivery = Delivery(targetSessionID: SessionID("s"), kind: .message, crew: message)

        try await runner.send(delivery.sent, recording: delivery.crewPayload)

        let turn = try #require(await runner.turns.first)
        #expect(turn.text == message.sent)
        #expect(CrewMessage.decode(try #require(turn.recording)) == message)
    }

    @Test("a turn with nothing to record still goes out under one argument")
    func oneArgumentStillWorks() async throws {
        let runner = RecordingRunner()

        try await runner.send("list the technologies used")

        let turn = try #require(await runner.turns.first)
        #expect(turn.text == "list the technologies used")
        #expect(turn.recording == nil)
    }
}

private actor RecordingRunner: SessionRunner {
    struct Turn: Sendable {
        var text: String
        var recording: Data?
    }

    private(set) var turns: [Turn] = []

    nonisolated var agentKind: AgentKind { .claudeCode }
    nonisolated var events: AsyncStream<AgentEvent> { AsyncStream { $0.finish() } }
    var isProcessAlive: Bool { false }

    func send(_ text: String, recording: Data?) async throws {
        turns.append(Turn(text: text, recording: recording))
    }

    nonisolated func cancelNow() {}
    nonisolated func terminateNow() {}
    func answer(requestID: String, decision: PermissionDecision) async {}
}

@Suite("What stopping a subagent leaves behind", .tags(.persistence), .scratchDirectory)
struct CrewStopTests {
    private func makeCrew(_ store: Store) async throws -> (Workspace, Session, Session) {
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id,
            name: "crew",
            branch: "unifieddev/crew",
            path: TestScratch.unique("worktree"),
            baseBranch: "main"
        ))
        let parent = try await store.upsert(Session(workspaceID: workspace.id, title: "Chat"))
        let member = try await store.upsert(Session(
            workspaceID: workspace.id, parentSessionID: parent.id, title: "reader"
        ))
        return (workspace, parent, member)
    }

    @Test("the conversation is still there to read after the agent is stopped")
    func archivesRatherThanDeletes() async throws {
        let store = try makeTestStore("crew-stop")
        let (_, _, member) = try await makeCrew(store)
        let brief = CrewMessage.brief(from: "Chat", task: "Read the cascade.")
        try await store.appendNext(sessionID: member.id, kind: .crew, payload: brief.payload())
        try await store.appendNext(
            sessionID: member.id, kind: .assistantText, payload: Data("{}".utf8)
        )

        _ = try await store.update(sessionID: member.id) { $0.archivedAt = Date() }

        let stopped = try #require(try await store.session(id: member.id))
        #expect(stopped.archivedAt != nil)
        #expect(stopped.title == "reader")
        let rows = try await store.messages(sessionID: member.id)
        #expect(rows.count == 2)
        #expect(rows.first?.kind == .crew)
        #expect(CrewMessage.decode(try #require(rows.first?.payload)) == brief)
    }

    @Test("the row leaves the sidebar and the name comes free")
    func freesTheNameAndTheRow() async throws {
        let store = try makeTestStore("crew-stop-name")
        let (workspace, parent, member) = try await makeCrew(store)

        _ = try await store.update(sessionID: member.id) { $0.archivedAt = Date() }

        #expect(try await store.crew(of: parent.id).isEmpty)
        #expect(try await store.crew(inWorkspace: workspace.id).isEmpty)
        #expect(try await store.crewByWorkspace()[workspace.id] == nil)

        let existing = Set(try await store.crew(of: parent.id).map(\.title))
        let started = Crew.start(
            name: "reader", existing: existing, running: 0, callerIsSubagent: false
        )
        #expect(started == .success("reader"))
    }
}

@Suite("What a crew message's caller is told about when it lands")
struct CrewDeliverySentenceTests {
    @Test("a backend that takes a message mid turn is not described as making the caller wait")
    func midTurnBackendsPromiseNoWait() {
        for agent in AgentKind.allCases where agent.acceptsMidTurnMessage {
            let sentence = Crew.deliverySentence(to: agent)
            #expect(sentence.contains("inside the turn it is running"))
            #expect(!sentence.contains("when that turn ends"))
        }
    }

    @Test("a backend that cannot still says so, because there the wait is real")
    func otherBackendsStillNameTheTurn() {
        for agent in AgentKind.allCases where !agent.acceptsMidTurnMessage {
            #expect(
                Crew.deliverySentence(to: agent)
                    == "If it is mid turn it will read this when that turn ends."
            )
        }
    }

    @Test("every backend gets a sentence, and it is one sentence")
    func everyBackendSpeaks() {
        for agent in AgentKind.allCases {
            let sentence = Crew.deliverySentence(to: agent)
            #expect(!sentence.isEmpty)
            #expect(sentence.hasSuffix("."))
        }
    }
}
