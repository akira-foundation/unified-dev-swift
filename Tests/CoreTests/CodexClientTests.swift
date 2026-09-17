import Testing
import Foundation
@testable import Core

private func makeClient(_ box: ProcessBox, codexHome: String? = nil) -> CodexClient {
    CodexClient(
        configuration: CodexClient.Configuration(cwd: "/tmp/codex-work", codexHome: codexHome),
        makeProcess: box.factory
    )
}

private actor EventCollector {
    private var collected: [CodexEvent] = []

    func consume(_ client: CodexClient, until predicate: @escaping @Sendable (CodexEvent) -> Bool) async {
        for await event in client.events {
            collected.append(event)
            if predicate(event) { return }
        }
    }

    var events: [CodexEvent] { collected }
}

@Suite struct CodexClientTests {
    @Test func launchesAppServerOnStdio() {
        let launch = CodexClient.launch(CodexClient.Configuration(
            cwd: "/tmp/w",
            codexHome: "/tmp/scratch-home"
        ))
        #expect(launch.executable == "codex")
        #expect(launch.arguments == ["app-server", "--listen", "stdio://"])
        #expect(launch.cwd == "/tmp/w")
        #expect(launch.environment["CODEX_HOME"] == "/tmp/scratch-home")
    }

    @Test func leavesCodexHomeAloneWhenNoneIsGiven() {
        let launch = CodexClient.launch(CodexClient.Configuration(cwd: "/tmp/w", environment: [:]))
        #expect(launch.environment["CODEX_HOME"] == nil)
    }

    @Test func doesTheHandshakeInOrder() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()

        #expect(box.process.sentMethods == ["initialize", "initialized"])
        #expect(await client.isReady)

        let handshake = box.process.stdin.compactMap(JSONValue.parse)
        #expect(handshake[0]["id"] != nil)
        #expect(handshake[1]["id"] == nil)
        #expect(handshake[0]["params"]?["clientInfo"]?["name"]?.stringValue == "Unified Dev")
    }

    @Test func startsAThreadAndReadsItsIDOutOfTheReply() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        box.reply(to: "thread/start", with: .object([
            "thread": .object(["id": .string("01a02144-3b7e-7233-97f2-73ebd5105085")]),
            "model": .string("gpt-5.6-sol"),
            "reasoningEffort": .null,
        ]))

        try await client.start()
        let thread = try await client.startThread(
            model: "gpt-5.6-sol",
            approvalPolicy: .onRequest,
            sandbox: .workspaceWrite
        )

        #expect(thread.id == "01a02144-3b7e-7233-97f2-73ebd5105085")
        #expect(thread.model == "gpt-5.6-sol")
        #expect(thread.effort == nil)

        let start = try #require(box.process.sentFrame { $0["method"]?.stringValue == "thread/start" })
        #expect(start["params"]?["sandbox"]?.stringValue == "workspace-write")
        #expect(start["params"]?["approvalPolicy"]?.stringValue == "on-request")
        #expect(start["params"]?["cwd"]?.stringValue == "/tmp/codex-work")
    }

    @Test func sendsATurnWithItsOwnModelAndEffort() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        box.reply(to: "turn/start", with: .object([
            "turn": .object([
                "id": .string("turn-1"),
                "status": .string("inProgress"),
                "items": .array([]),
            ]),
        ]))

        try await client.start()
        let turn = try await client.startTurn(
            threadID: "thread-1",
            input: [.text("hello"), .localImage(path: "/tmp/shot.png")],
            model: "gpt-5.6-luna",
            effort: "medium"
        )

        #expect(turn.id == "turn-1")
        #expect(turn.status == .inProgress)

        let sent = try #require(box.process.sentFrame { $0["method"]?.stringValue == "turn/start" })
        let params = try #require(sent["params"])
        #expect(params["model"]?.stringValue == "gpt-5.6-luna")
        #expect(params["effort"]?.stringValue == "medium")
        #expect(params["input"]?[0]?["type"]?.stringValue == "text")
        #expect(params["input"]?[1]?["type"]?.stringValue == "localImage")
        #expect(params["input"]?[1]?["path"]?.stringValue == "/tmp/shot.png")
    }

    @Test func leavesAnEmptyEffortOutOfTheTurn() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()
        _ = try? await client.startTurn(threadID: "t", input: [.text("hi")], effort: "")

        let sent = try #require(box.process.sentFrame { $0["method"]?.stringValue == "turn/start" })
        #expect(sent["params"]?["effort"] == nil)
    }

    @Test func interruptSendsBothIDs() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()
        try await client.interruptTurn(threadID: "thread-1", turnID: "turn-1")

        let sent = try #require(box.process.sentFrame { $0["method"]?.stringValue == "turn/interrupt" })
        #expect(sent["params"]?["threadId"]?.stringValue == "thread-1")
        #expect(sent["params"]?["turnId"]?.stringValue == "turn-1")
    }

    @Test func aServerErrorReachesTheCallerAsAThrow() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        box.fail("thread/start", code: -32600, message: "Invalid request: unknown variant `readOnly`")

        try await client.start()
        await #expect(throws: CodexRPCError.self) {
            _ = try await client.startThread()
        }
    }

    @Test func endingTheProcessFailsEveryPendingRequest() async throws {
        let box = ProcessBox()
        box.ignore("thread/list")
        let client = makeClient(box)
        try await client.start()

        let pending = Task { try await client.send("thread/list", params: nil) }
        try await Task.sleep(for: .milliseconds(30))
        box.process.endOutput()

        await #expect(throws: CodexClientError.self) { try await pending.value }
    }

    @Test func replaysARecordedTurnAsEvents() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()

        let collector = EventCollector()
        let consuming = Task {
            await collector.consume(client) { event in
                if case .turnCompleted = event { return true }
                return false
            }
        }
        try await Task.sleep(for: .milliseconds(20))

        for line in try fixtureLines("codex-turn.ndjson") {
            guard JSONValue.parse(line)?["method"] != nil else { continue }
            box.process.emit(line)
        }
        await consuming.value

        let events = await collector.events
        let deltas = events.compactMap { event -> String? in
            if case .agentMessageDelta(let delta) = event { return delta.text }
            return nil
        }
        #expect(deltas.joined() == "unifieddev")

        let completed = events.contains { event in
            if case .turnCompleted(let turn) = event { return turn.status == .completed }
            return false
        }
        #expect(completed)
    }

    @Test func answersAnApprovalTheServerAsked() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()

        let collector = EventCollector()
        let consuming = Task {
            await collector.consume(client) { event in
                if case .approval = event { return true }
                return false
            }
        }
        try await Task.sleep(for: .milliseconds(20))

        let ask = try fixtureLines("codex-approval.ndjson").first { line in
            JSONValue.parse(line)?["method"]?.stringValue == "item/fileChange/requestApproval"
        }
        box.process.emit(try #require(ask))
        await consuming.value

        let approvals = await collector.events.compactMap { event -> CodexApprovalRequest? in
            if case .approval(let request) = event { return request }
            return nil
        }
        let request = try #require(approvals.first)
        #expect(request.kind == .fileChange)

        await client.answer(request, decision: .decline)
        let answer = try #require(box.process.stdin.last.flatMap(JSONValue.parse))
        #expect(answer["id"]?.intValue == 0)
        #expect(answer["result"]?["decision"]?.stringValue == "decline")
    }

    @Test func refusesAServerRequestItDoesNotImplement() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()

        box.process.emit(#"{"id":3,"method":"attestation/generate","params":{}}"#)
        try await Task.sleep(for: .milliseconds(50))

        let refusal = try #require(box.process.stdin.last.flatMap(JSONValue.parse))
        #expect(refusal["id"]?.intValue == 3)
        #expect(refusal["error"]?["code"]?.intValue == -32601)
        #expect(refusal["error"]?["message"]?.stringValue?.contains("attestation/generate") == true)
    }

    @Test func keepsStderrOutOfTheFramesAndInTheDiagnostics() async throws {
        let box = ProcessBox()
        let client = makeClient(box)
        try await client.start()

        box.process.emitError("ERROR codex_core::tools::router: error=patch rejected by user")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await client.diagnostics.contains { $0.contains("patch rejected by user") })
    }
}

@Suite("A request that is never answered")
struct CodexRequestTimeoutTests {
    @Test("the default budget is generous rather than tight")
    func theBudgetIsGenerous() {
        #expect(CodexClient.requestTimeout >= .seconds(60))
    }

    @Test("giving up names the method and the budget it spent")
    func theErrorSaysWhatWasWaitedOn() {
        let error = CodexClientError.timedOut(method: "thread/start", seconds: 120)
        #expect(error == .timedOut(method: "thread/start", seconds: 120))
        #expect(error != .timedOut(method: "turn/start", seconds: 120))
        #expect(error != .connectionClosed("thread/start"))
    }

    @Test("timeouts are described without exposing RPC method names")
    func timeoutDescriptionsAreForPeople() {
        let resume = CodexClientError.timedOut(method: "thread/resume", seconds: 120)
        let turn = CodexClientError.timedOut(method: "turn/start", seconds: 120)

        #expect(resume.readableMessage == "Codex did not respond while reopening this conversation.")
        #expect(turn.readableMessage == "Codex did not accept the message in time.")
        #expect(!resume.readableMessage.contains("thread/resume"))
    }
}
