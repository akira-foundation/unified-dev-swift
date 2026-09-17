import Testing
import Foundation
@testable import Core

private func makeSession(_ store: Store, permissionMode: PermissionMode = .acceptEdits) async throws -> Session {
    let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
    let workspace = try await store.upsert(Workspace(
        repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main"
    ))
    return try await store.upsert(Session(
        workspaceID: workspace.id, model: "opus", permissionMode: permissionMode
    ))
}

private final class FakeProcess: AgentProcessing, @unchecked Sendable {
    let launch: AgentLaunch
    private let lock = NSLock()
    private var written: [String] = []
    private var terminated = false
    private var killed = false
    private var running = true
    private let status: Int32

    private let stdoutContinuation: AsyncThrowingStream<String, Error>.Continuation
    private let stderrContinuation: AsyncStream<String>.Continuation

    let lines: AsyncThrowingStream<String, Error>
    let errorLines: AsyncStream<String>

    init(launch: AgentLaunch, status: Int32 = 0) {
        self.launch = launch
        self.status = status

        var out: AsyncThrowingStream<String, Error>.Continuation!
        lines = AsyncThrowingStream(bufferingPolicy: .unbounded) { out = $0 }
        stdoutContinuation = out

        var err: AsyncStream<String>.Continuation!
        errorLines = AsyncStream(bufferingPolicy: .unbounded) { err = $0 }
        stderrContinuation = err
    }

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    var exitStatus: Int32 {
        get async { status }
    }

    func writeLine(_ text: String) {
        lock.lock(); written.append(text); lock.unlock()
    }

    func closeStdin() {}

    func terminate() {
        lock.lock(); terminated = true; running = false; lock.unlock()
        stdoutContinuation.finish()
        stderrContinuation.finish()
    }

    func kill() {
        lock.lock(); killed = true; running = false; lock.unlock()
    }

    var stdin: [String] {
        lock.lock(); defer { lock.unlock() }
        return written
    }

    var wasTerminated: Bool {
        lock.lock(); defer { lock.unlock() }
        return terminated
    }

    func emit(_ line: String) {
        stdoutContinuation.yield(line)
    }

    func emitError(_ line: String) {
        stderrContinuation.yield(line)
    }

    func endOutput() {
        lock.lock(); running = false; lock.unlock()
        stdoutContinuation.finish()
        stderrContinuation.finish()
    }
}

private final class ProcessRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var made: [FakeProcess] = []
    private let status: Int32

    init(status: Int32 = 0) {
        self.status = status
    }

    var factory: @Sendable (AgentLaunch) -> any AgentProcessing {
        { launch in
            let process = FakeProcess(launch: launch, status: self.status)
            self.append(process)
            return process
        }
    }

    private func append(_ process: FakeProcess) {
        lock.lock(); made.append(process); lock.unlock()
    }

    var all: [FakeProcess] {
        lock.lock(); defer { lock.unlock() }
        return made
    }

    var last: FakeProcess? { all.last }
}

@Suite("AgentRunner argv", .tags(.agentProtocol), .scratchDirectory)
struct AgentRunnerArgvTests {
    @Test("Ask Unified Dev receives host instructions on new and resumed conversations",
          arguments: [false, true], [false, true])
    func askAppInstructions(hasWorkspace: Bool, resumed: Bool) {
        let session = Session(workspaceID: hasWorkspace ? WorkspaceID("w") : nil)
        let argv = AgentRunner.argv(session: session, resume: resumed ? "existing-chat" : nil)

        #expect(value(of: "--append-system-prompt", in: argv) == (hasWorkspace ? nil : AskConversation.instructions))
        #expect(!argv.contains("--system-prompt"))
        #expect(value(of: "--resume", in: argv) == (resumed ? "existing-chat" : nil))
    }

    private func value(of flag: String, in argv: [String]) -> String? {
        guard let index = argv.firstIndex(of: flag), argv.indices.contains(index + 1) else { return nil }
        return argv[index + 1]
    }

    @Test("builds the invocation docs/PROTOCOL.md specifies")
    func buildsArgv() {
        let session = Session(workspaceID: WorkspaceID("w"), model: "opus", effort: "high", permissionMode: .acceptEdits)
        #expect(AgentRunner.argv(session: session, resume: nil) == [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--include-partial-messages",
            "--verbose",
            "--permission-mode", "acceptEdits",
            "--allow-dangerously-skip-permissions",
            "--permission-prompt-tool", "stdio",
            "--model", "opus",
            "--effort", "high",
        ])
    }

    @Test("every session can be asked, whatever mode it is in")
    func alwaysAsks() {
        for mode in PermissionMode.allCases {
            let argv = AgentRunner.argv(session: Session(workspaceID: WorkspaceID("w"), permissionMode: mode), resume: nil)

            #expect(value(of: "--permission-prompt-tool", in: argv) == "stdio")
        }
    }

    @Test("the reasoning effort the user picked reaches the CLI")
    func passesEffort() {
        let session = Session(workspaceID: WorkspaceID("w"), effort: "high")

        #expect(value(of: "--effort", in: AgentRunner.argv(session: session, resume: nil)) == "high")
    }

    @Test(
        "every level the composer offers is a level the CLI accepts",
        arguments: ["low", "medium", "high", "xhigh", "max"]
    )
    func everyComposerEffort(level: String) {
        let session = Session(workspaceID: WorkspaceID("w"), effort: level)

        #expect(value(of: "--effort", in: AgentRunner.argv(session: session, resume: nil)) == level)
    }

    @Test("an effort Unified Dev does not recognise is still passed through")
    func unknownEffort() {
        let session = Session(workspaceID: WorkspaceID("w"), effort: "ultracode")

        #expect(value(of: "--effort", in: AgentRunner.argv(session: session, resume: nil)) == "ultracode")
    }

    @Test("an empty effort sends no flag at all rather than an empty one")
    func emptyEffort() {
        for blank in ["", "   "] {
            let argv = AgentRunner.argv(session: Session(workspaceID: WorkspaceID("w"), effort: blank), resume: nil)

            #expect(!argv.contains("--effort"), "a blank effort still sent the flag")
        }
    }

    @Test("fast mode is off unless it is on, and off sends nothing")
    func fastModeOff() {
        let argv = AgentRunner.argv(session: Session(workspaceID: WorkspaceID("w")), resume: nil, isFastMode: false)

        #expect(!argv.contains("--thinking"))
    }

    @Test("fast mode turns thinking off")
    func fastModeOn() {
        let argv = AgentRunner.argv(session: Session(workspaceID: WorkspaceID("w")), resume: nil, isFastMode: true)

        #expect(value(of: "--thinking", in: argv) == "disabled")
        #expect(["enabled", "adaptive", "disabled"].contains(value(of: "--thinking", in: argv) ?? ""))
    }

    @Test("the fast mode key is the one already in the database")
    func fastModeKeyIsStable() {
        #expect(ComposerControls.fastModeKey(sessionID: SessionID("abc")) == "session.abc.fastMode")
    }

    @Test("the output style the user picked reaches the CLI")
    func passesOutputStyle() {
        let argv = AgentRunner.argv(
            session: Session(workspaceID: WorkspaceID("w")), resume: nil, outputStyle: "Concise"
        )

        #expect(value(of: "--settings", in: argv) == #"{"outputStyle":"Concise"}"#)
    }

    @Test(
        "every built in style the composer offers reaches the CLI by name",
        arguments: ["Proactive", "Concise", "Explanatory", "Learning"]
    )
    func everyBuiltInOutputStyle(name: String) {
        let argv = AgentRunner.argv(
            session: Session(workspaceID: WorkspaceID("w")), resume: nil, outputStyle: name
        )

        #expect(value(of: "--settings", in: argv) == #"{"outputStyle":"\#(name)"}"#)
        #expect(OutputStyle.builtIns.contains { $0.name == name })
    }

    @Test(
        "the default output style sends no settings at all",
        arguments: [String?](["", "   ", "default", nil])
    )
    func defaultOutputStyleSendsNothing(name: String?) {
        let argv = AgentRunner.argv(
            session: Session(workspaceID: WorkspaceID("w")), resume: nil, outputStyle: name
        )

        #expect(!argv.contains("--settings"), "the default still sent a settings object")
    }

    @Test("a custom style name is encoded rather than pasted in")
    func encodesCustomOutputStyle() throws {
        let argv = AgentRunner.argv(
            session: Session(workspaceID: WorkspaceID("w")), resume: nil, outputStyle: #"Say "hi""#
        )
        let settings = try #require(value(of: "--settings", in: argv))
        let object = try JSONSerialization.jsonObject(with: Data(settings.utf8)) as? [String: String]

        #expect(object == ["outputStyle": #"Say "hi""#])
    }

    @Test("the settings object is passed once and holds only what Unified Dev states")
    func settingsFlagIsUsedOnce() {
        let argv = AgentRunner.argv(
            session: Session(workspaceID: WorkspaceID("w"), effort: "max"),
            resume: "abc",
            isFastMode: true,
            outputStyle: "Explanatory"
        )

        #expect(argv.filter { $0 == "--settings" }.count == 1)
    }

    @Test("the output style key is the one already in the database")
    func outputStyleKeyIsStable() {
        #expect(ComposerControls.outputStyleKey(sessionID: SessionID("abc")) == "session.abc.outputStyle")
    }

    @Test("no flag is left without its value")
    func noDanglingFlags() {
        let argv = AgentRunner.argv(
            session: Session(workspaceID: WorkspaceID("w"), effort: "max"),
            resume: "abc",
            isFastMode: true,
            outputStyle: "Concise"
        )
        let valueless: Set<String> = ["--verbose", "--include-partial-messages", "--allow-dangerously-skip-permissions"]

        for (index, item) in argv.enumerated() where item.hasPrefix("--") && !valueless.contains(item) {
            #expect(argv.indices.contains(index + 1), "\(item) has nothing after it")
            #expect(!argv[index + 1].hasPrefix("--"), "\(item) is followed by another flag")
        }
    }

    @Test("appends resume when there is an agent session to resume")
    func appendsResume() throws {
        let session = Session(workspaceID: WorkspaceID("w"), model: "sonnet")
        let argv = AgentRunner.argv(session: session, resume: "f93932c9-cf0b-40d8-881c-ac75db3f8740")
        #expect(argv.suffix(2) == ["--resume", "f93932c9-cf0b-40d8-881c-ac75db3f8740"])
        let model = try #require(argv.firstIndex(of: "--model"))
        #expect(argv[model + 1] == "sonnet")
    }

    @Test("leaves resume off for an empty or missing id")
    func skipsEmptyResume() {
        let session = Session(workspaceID: WorkspaceID("w"))
        #expect(AgentRunner.argv(session: session, resume: "").contains("--resume") == false)
        #expect(AgentRunner.argv(session: session, resume: nil).contains("--resume") == false)
    }

    @Test("maps every permission mode to a value the CLI accepts", arguments: [
        (PermissionMode.auto, "auto"),
        (.acceptEdits, "acceptEdits"),
        (.autoReview, "auto"),
        (.bypassPermissions, "bypassPermissions"),
        (.plan, "plan"),
    ])
    func mapsPermissionModes(mode: PermissionMode, cliValue: String) throws {
        let session = Session(workspaceID: WorkspaceID("w"), permissionMode: mode)
        let argv = AgentRunner.argv(session: session, resume: nil)
        let index = try #require(argv.firstIndex(of: "--permission-mode"))
        #expect(argv[index + 1] == cliValue)
        #expect(mode.cliValue == cliValue)
    }

    @Test("covers every permission mode the app can be in")
    func coversEveryPermissionMode() {
        #expect(PermissionMode.allCases.count == 5)
    }

    @Test("launches in the worktree, resuming once the agent session is known")
    func buildsLaunch() async throws {
        let store = try makeTestStore("agent")
        var session = try await makeSession(store)
        session.agentSessionID = "resume-me"
        let runner = AgentRunner(workspacePath: "/tmp/worktree", session: session, store: store)

        let launch = await runner.launch()
        #expect(launch.executable == "claude")
        #expect(launch.cwd == "/tmp/worktree")
        #expect(launch.arguments.suffix(2) == ["--resume", "resume-me"])
        #expect(launch.environment["PATH"]?.contains("/usr/bin") == true)
    }

    @Test("encodes a user turn as one line of NDJSON")
    func encodesTurn() throws {
        let line = try AgentRunner.encodeTurn("write /tmp/out.txt \"now\"")
        #expect(line.contains("\n") == false)

        let json = try #require(JSONValue.parse(line))
        #expect(json["type"]?.stringValue == "user")
        #expect(json["message"]?["role"]?.stringValue == "user")
        #expect(json["message"]?["content"]?[0]?["type"]?.stringValue == "text")
        #expect(json["message"]?["content"]?[0]?["text"]?.stringValue == "write /tmp/out.txt \"now\"")
    }
}

@Suite("AgentRunner persistence", .tags(.agentProtocol, .persistence), .scratchDirectory)
struct AgentRunnerPersistenceTests {
    @Test("stores every transcript row in order with the raw JSON")
    func storesTranscript() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let lines = try fixtureSessionLines()
        for event in lines.compactMap({ AgentEvent.decode(line: $0) }) {
            await runner.ingest(event)
        }

        let messages = try await store.messages(sessionID: session.id)
        #expect(messages.count == 25)
        #expect(messages.map(\.seq) == Array(0..<25))
        #expect(messages.filter { $0.kind == .toolUse }.count == 2)
        #expect(messages.filter { $0.kind == .toolResult }.count == 2)
        #expect(messages.filter { $0.kind == .assistantText }.count == 2)
        #expect(messages.filter { $0.kind == .result }.count == 1)
        #expect(messages.filter { $0.kind == .notice }.count == 1)

        let stored = try #require(messages.first { $0.kind == .toolUse })
        #expect(JSONValue.parse(stored.payload)?["type"]?.stringValue == "assistant")
    }

    @Test("files tool use rows under their tool_use id so results can pair up")
    func filesRefIDs() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        for event in try fixtureSessionLines().compactMap({ AgentEvent.decode(line: $0) }) {
            await runner.ingest(event)
        }

        let paired = try await store.message(sessionID: session.id, refID: "toolu_01PpKZErcdXrhaSWzLBno4Ra")
        #expect(paired != nil)
        #expect(paired?.kind == .toolResult)

        let all = try await store.messages(sessionID: session.id)
        let refs = all.filter { $0.refID == "toolu_01TWLhjSjYuicXQJSDpTGa2V" }
        #expect(refs.map(\.kind) == [.toolUse, .toolResult])
    }

    @Test("a turn the CLI starts by itself marks the session running")
    func aTurnTheCLIStartsByItselfIsRunning() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let line = """
        {"type":"system","subtype":"init","session_id":"s-1","cwd":"/tmp/w","model":"sonnet"}
        """
        await runner.ingest(try #require(AgentEvent.decode(line: line)))

        let stored = try #require(try await store.session(id: session.id))
        #expect(stored.state == .running)
        #expect(stored.agentSessionID == "s-1")
    }

    @Test("and the same session goes back to idle when that turn's result arrives")
    func theSelfStartedTurnStillEndsOnItsResult() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let initLine = """
        {"type":"system","subtype":"init","session_id":"s-1","cwd":"/tmp/w","model":"sonnet"}
        """
        let resultLine = """
        {"type":"result","subtype":"success","is_error":false,"num_turns":3,"duration_api_ms":31662,\
        "duration_ms":31662,"result":"Waiting on the fix-round implementer.",\
        "origin":{"kind":"task-notification"},"session_id":"s-1","usage":{},"total_cost_usd":0}
        """
        await runner.ingest(try #require(AgentEvent.decode(line: initLine)))
        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))

        #expect(try await store.session(id: session.id)?.state == .idle)
    }

    @Test("drops stream deltas from the transcript unless asked to keep them")
    func dropsStreamDeltas() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        await runner.ingest(.streamDelta(.text("hel")))
        await runner.ingest(.streamDelta(.text("lo")))
        #expect(try await store.messageCount(sessionID: session.id) == 0)

        await runner.setPersistsStreamDeltas(true)
        await runner.ingest(.streamDelta(.blockFinished))
        #expect(try await store.messageCount(sessionID: session.id) == 1)
    }

    @Test("persists the agent session id the moment init arrives")
    func persistsAgentSessionID() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let line = try #require(try fixtureSessionLines().first { $0.contains("\"subtype\":\"init\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: line)))

        let reloaded = try await store.session(id: session.id)
        #expect(reloaded?.agentSessionID == "f93932c9-cf0b-40d8-881c-ac75db3f8740")
        #expect(await runner.launch().arguments.suffix(2) == ["--resume", "f93932c9-cf0b-40d8-881c-ac75db3f8740"])
    }

    @Test("rolls the result usage into the session")
    func updatesSessionOnResult() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        let resultLine = try #require(try fixtureSessionLines().last { $0.contains("\"type\":\"result\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))

        let reloaded = try #require(try await store.session(id: session.id))
        #expect(reloaded.inputTokens == 6)
        #expect(reloaded.outputTokens == 360)
        #expect(abs(reloaded.costUSD - 0.119112) < 0.000001)
        #expect(reloaded.contextTokens == 0)
        #expect(reloaded.state == .idle)

        await runner.ingest(try #require(AgentEvent.decode(line: resultLine)))
        #expect(try await store.session(id: session.id)?.outputTokens == 720)

        let stored = try await store.messages(sessionID: session.id)
        #expect(stored.map(\.durationMS) == [7880, 7880])
    }

    @Test("records the context the model had, not the turn's total")
    func recordsContextWindowUsage() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)

        for event in try fixtureSessionLines().compactMap({ AgentEvent.decode(line: $0) }) {
            await runner.ingest(event)
        }

        let reloaded = try #require(try await store.session(id: session.id))
        #expect(reloaded.contextTokens == 2 + 215 + 38_137)
        #expect(reloaded.contextTokens != 6 + 100_420 + 13_928)
    }

    @Test("marks the session failed when the result says so")
    func failsOnErrorResult() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session.with { $0.apply(.turnStarted) }, store: store
        )

        let line = #"""
        {"type":"result","subtype":"error_max_turns","is_error":true,"duration_ms":10,\
        "num_turns":9,"session_id":"s1","total_cost_usd":0.5,"result":"","uuid":"u"}
        """#.replacingOccurrences(of: "\\\n", with: "")
        await runner.ingest(try #require(AgentEvent.decode(line: line)))

        #expect(try await store.session(id: session.id)?.state == .failed)
    }

    @Test("a result for a turn Unified Dev never started closes nothing")
    func ignoresAStrayResult() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session.with { $0.apply(.turnStarted) }, store: store
        )

        let line = #"""
        {"type":"result","subtype":"success","is_error":false,"duration_api_ms":0,"num_turns":0,\
        "session_id":"s1","total_cost_usd":0,"result":"","origin":{"kind":"task-notification"},\
        "duration_ms":60,"uuid":"u"}
        """#.replacingOccurrences(of: "\\\n", with: "")
        await runner.ingest(try #require(AgentEvent.decode(line: line)))

        #expect(await runner.currentSession.state == .running)

        let stored = try await store.messages(sessionID: session.id)
        #expect(stored.map(\.kind) == [.system])
        #expect(stored.first?.durationMS == nil)
    }

    @Test("the real result behind a stray one still ends the turn")
    func stillEndsOnTheRealResult() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session.with { $0.apply(.turnStarted) }, store: store
        )

        let stray = #"""
        {"type":"result","subtype":"success","is_error":false,"duration_api_ms":0,"num_turns":0,\
        "result":"","origin":{"kind":"task-notification"},"duration_ms":60,"uuid":"u1"}
        """#.replacingOccurrences(of: "\\\n", with: "")
        await runner.ingest(try #require(AgentEvent.decode(line: stray)))

        let real = try #require(try fixtureSessionLines().last { $0.contains("\"type\":\"result\"") })
        await runner.ingest(try #require(AgentEvent.decode(line: real)))

        #expect(try await store.session(id: session.id)?.state == .idle)
        #expect(try await store.messages(sessionID: session.id).map(\.kind) == [.system, .result])
    }

    @Test("continues the sequence of an already stored transcript")
    func continuesSeq() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        try await store.append(Message(
            sessionID: session.id, seq: 0, kind: .user, payload: Data("{}".utf8)
        ))
        try await store.append(Message(
            sessionID: session.id, seq: 1, kind: .assistantText, payload: Data("{}".utf8)
        ))

        let runner = AgentRunner(workspacePath: "/tmp/w", session: session, store: store)
        await runner.ingest(.error(AgentError(message: "boom", raw: Data("{}".utf8))))
        await runner.ingest(.error(AgentError(message: "boom", raw: Data("{}".utf8))))

        let messages = try await store.messages(sessionID: session.id)
        #expect(messages.map(\.seq) == [0, 1, 2, 3])
        #expect(messages.suffix(2).allSatisfy { $0.kind == .error })
    }
}

@Suite("AgentRunner process", .tags(.agentProtocol, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct AgentRunnerProcessTests {
    @Test("sends a turn, replays the stream, and lands idle")
    func runsATurn() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        let collector = Task {
            var events: [AgentEvent] = []
            for await event in runner.events {
                events.append(event)
                if case .result = event { break }
            }
            return events
        }

        try await runner.send("do the thing")
        #expect(await runner.isRunning)

        let process = try #require(recorder.last)
        #expect(process.launch.arguments.contains("--include-partial-messages"))
        #expect(process.stdin.count == 1)
        #expect(JSONValue.parse(process.stdin[0])?["message"]?["content"]?[0]?["text"]?.stringValue
            == "do the thing")

        for line in try fixtureSessionLines() { process.emit(line) }
        let received = await collector.value
        process.endOutput()

        #expect(received.count == 55)
        await waitUntil("the runner stopped") { await runner.isRunning == false }

        let reloaded = try #require(try await store.session(id: session.id))
        #expect(reloaded.agentSessionID == "f93932c9-cf0b-40d8-881c-ac75db3f8740")
        #expect(reloaded.state == .idle)
        #expect(reloaded.outputTokens == 360)

        #expect(try await store.messageCount(sessionID: session.id) == 26)
        let first = try await store.messages(sessionID: session.id)[0]
        #expect(first.kind == .user)
    }

    @Test("the stored output style reaches the process the runner spawns")
    func spawnsWithTheStoredOutputStyle() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        try await store.setSetting(ComposerControls.outputStyleKey(sessionID: session.id), "Concise")

        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("hello")

        let process = try #require(recorder.last)
        let index = try #require(process.launch.arguments.firstIndex(of: "--settings"))
        #expect(process.launch.arguments[index + 1] == #"{"outputStyle":"Concise"}"#)
    }

    @Test("the stored executable reaches the process the runner spawns")
    func spawnsWithTheStoredExecutable() async throws {
        let store = try makeTestStore("agent-executable")
        let session = try await makeSession(store)
        try await store.setSetting(
            AgentCatalog.executablePathSettingKey(.claudeCode),
            "/tmp/tools/claude"
        )

        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("hello")

        #expect(try #require(recorder.last).launch.executable == "/tmp/tools/claude")
    }

    @Test("a session with no output style spawns without a settings object")
    func spawnsWithoutSettingsByDefault() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("hello")

        let process = try #require(recorder.last)
        #expect(!process.launch.arguments.contains("--settings"))
    }

    @Test("records an error row and fails the session on a non-zero exit with no result")
    func failsWithoutResult() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder(status: 2)
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("hello")
        let process = try #require(recorder.last)
        process.emitError("error: not logged in")
        process.emit(#"{"type":"system","subtype":"status","status":"requesting","session_id":"s"}"#)
        process.endOutput()

        await waitUntil("the session was marked failed") { (try? await store.session(id: session.id)?.state) == .failed }

        let reloaded = try #require(try await store.session(id: session.id))
        #expect(reloaded.state == .failed)

        let errors = try await store.messages(sessionID: session.id).filter { $0.kind == .error }
        #expect(errors.count == 1)
        let payload = try #require(JSONValue.parse(errors[0].payload))
        #expect(payload["status"]?.intValue == 2)
        #expect(payload["stderr"]?.stringValue == "error: not logged in")
    }

    @Test("a clean exit in the middle of a turn ends it rather than leaving it running")
    func cleanExitMidTurnEndsTheTurn() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder(status: 0)
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        let stream = runner.events
        let sawError = Task<Bool, Never> {
            for await event in stream {
                if case .error = event { return true }
            }
            return false
        }

        try await runner.send("run phpstan")
        let process = try #require(recorder.last)
        process.emit(#"{"type":"system","subtype":"init","session_id":"s","cwd":"/tmp/w"}"#)
        process.endOutput()

        await waitUntil("the session stopped claiming a turn was running") {
            (try? await store.session(id: session.id)?.state) == .failed
        }

        let errors = try await store.messages(sessionID: session.id).filter { $0.kind == .error }
        #expect(errors.count == 1)
        let exit = AgentExit.decode(errors[0].payload)
        #expect(exit.cause == .endedMidTurn)

        #expect(await sawError.value)
        #expect(await runner.isRunning == false)
    }

    @Test("a clean exit after a result reports nothing")
    func cleanExitAfterResultIsQuiet() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder(status: 0)
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("hello")
        let process = try #require(recorder.last)
        process.emit(#"""
        {"type":"result","subtype":"success","is_error":false,"duration_ms":10,"session_id":"s"}
        """#)
        process.endOutput()

        await waitUntil("the turn landed idle") { (try? await store.session(id: session.id)?.state) == .idle }

        let errors = try await store.messages(sessionID: session.id).filter { $0.kind == .error }
        #expect(errors.isEmpty)
    }

    @Test("cancelling terminates the process and marks the session cancelled")
    func cancels() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("long job")
        let process = try #require(recorder.last)

        await runner.cancel()
        #expect(process.wasTerminated)
        await waitUntil("the session was marked cancelled") { (try? await store.session(id: session.id)?.state) == .cancelled }
        #expect(try await store.session(id: session.id)?.state == .cancelled)
        #expect(await runner.isRunning == false)
    }

    @Test("cancelNow signals without awaiting the actor")
    func cancelsFromSyncCode() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("long job")
        let process = try #require(recorder.last)

        runner.cancelNow()
        #expect(process.wasTerminated)
        await waitUntil("the session was marked cancelled") { (try? await store.session(id: session.id)?.state) == .cancelled }
        #expect(try await store.session(id: session.id)?.state == .cancelled)
    }

    @Test("a second turn reuses the running process")
    func reusesProcess() async throws {
        let store = try makeTestStore("agent")
        let session = try await makeSession(store)
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )

        try await runner.send("first")
        try await runner.send("second")

        #expect(recorder.all.count == 1)
        #expect(recorder.last?.stdin.count == 2)
        recorder.last?.endOutput()
    }
}

private func fixtureSessionLines() throws -> [String] {
    try fixtureLines("session-basic.jsonl")
}

@Suite("AgentRunner permissions", .tags(.agentProtocol, .persistence), .scratchDirectory)
struct AgentRunnerPermissionTests {
    private func askLine(id: String = "req-1", toolUse: String = "toolu_01") -> String {
        PermissionAskTests.realAsk
            .replacingOccurrences(of: "2f9899b1-849f-4d1b-b4b2-9c6e1304b300", with: id)
            .replacingOccurrences(of: "toolu_01AtAvbhP1XGtDNmpbSCSBRf", with: toolUse)
    }

    private func ask(id: String = "req-1", toolUse: String = "toolu_01") -> PermissionAsk {
        guard case .permissionAsk(let ask) = AgentEvent.decode(line: askLine(id: id, toolUse: toolUse))! else {
            fatalError("the fixture stopped being a permission ask")
        }
        return ask
    }

    private func repoID(of session: Session, in store: Store) async throws -> RepoID {
        let workspaceID = try #require(session.workspaceID)
        return try #require(await store.workspace(id: workspaceID)).repoID
    }

    private func running(
        _ store: Store,
        session: Session
    ) async throws -> (runner: AgentRunner, process: FakeProcess) {
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )
        try await runner.send("go")
        let process = try #require(recorder.last)
        return (runner, process)
    }

    private func answers(on process: FakeProcess) -> [JSONValue] {
        process.stdin
            .compactMap(JSONValue.parse)
            .filter { $0["type"]?.stringValue == "control_response" }
    }

    @Test("a question makes the session waiting, which is not running")
    func waiting() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, _) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask()))

        #expect(await runner.currentSession.state == .waiting)
        let stored = try #require(await store.session(id: session.id))
        #expect(stored.state == .waiting)
        #expect(stored.state != .running)
    }

    @Test("the question is on the pile and in the transcript")
    func recorded() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, _) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask()))

        #expect(await runner.pendingAsks.map(\.requestID) == ["req-1"])
        #expect(try await store.pendingPermissionAsks(sessionID: session.id).count == 1)

        let rows = try await store.messages(sessionID: session.id)
        let row = try #require(rows.last { $0.kind == .permissionAsk })
        #expect(row.refID == "toolu_01")
    }

    @Test("plan approval changes the running and persisted mode and survives a new runner", arguments: PlanApproval.modes)
    func approvingPlan(mode: PermissionMode) async throws {
        let store = try makeTestStore("plan-runner")
        let session = try await makeSession(store, permissionMode: .plan)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(try PlanApprovalTests.ask()))

        await runner.answer(requestID: "plan-1", decision: .approvePlan(mode: mode))
        await runner.answer(requestID: "plan-1", decision: .approvePlan(mode: .bypassPermissions))

        let sent = answers(on: process)
        #expect(sent.count == 1)
        let answer = try #require(sent.first)
        #expect(answer["response"]?["response"]?["updatedPermissions"]?[0]?["mode"]?.stringValue == mode.cliValue)
        #expect(await runner.currentSession.permissionMode == mode)
        #expect(await runner.currentSession.state == .running)
        #expect(await runner.pendingAsks.isEmpty)
        let stored = try #require(await store.session(id: session.id))
        #expect(stored.permissionMode == mode)
        #expect(try await store.permissionAskDecisions(sessionID: session.id)["plan-1"] == "approve-plan-\(mode.rawValue)")
        let repo = try await repoID(of: session, in: store)
        #expect(try await store.permissionGrants(repoID: repo).isEmpty)

        let recorder = ProcessRecorder()
        let resumed = AgentRunner(workspacePath: "/tmp/w", session: stored, store: store, makeProcess: recorder.factory)
        try await resumed.send("continue")
        let arguments = try #require(recorder.last).launch.arguments
        let modeIndex = try #require(arguments.firstIndex(of: "--permission-mode"))
        #expect(arguments[modeIndex + 1] == mode.cliValue)
        await runner.cancel()
        await resumed.cancel()
    }

    @Test("the plan card offers the remembered implementation mode after storing the question")
    func planOffer() async throws {
        let store = try makeTestStore("plan-offer")
        let session = try await makeSession(store, permissionMode: .acceptEdits)
        try await store.updateSessionPreferences(id: session.id, permissionMode: .plan)
        let planned = try #require(await store.session(id: session.id))
        let (runner, _) = try await running(store, session: planned)
        await runner.ingest(.permissionAsk(try PlanApprovalTests.ask()))
        let rows = try await store.messages(sessionID: session.id)
        let row = try #require(rows.last { $0.kind == .permissionAsk })
        #expect(PermissionAsk.decode(payload: row.payload)?.implementationMode == .acceptEdits)
        #expect(await runner.pendingAsks.first?.implementationMode == .acceptEdits)
        await runner.cancel()
    }

    @Test("rejecting a plan leaves planning permissions intact")
    func rejectingPlan() async throws {
        let store = try makeTestStore("plan-reject")
        let session = try await makeSession(store, permissionMode: .plan)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(try PlanApprovalTests.ask()))
        await runner.answer(requestID: "plan-1", decision: .deny(message: PlanApproval.keepPlanningMessage, endsTurn: false))
        #expect(await runner.currentSession.permissionMode == .plan)
        #expect(try await store.session(id: session.id)?.permissionMode == .plan)
        #expect(answers(on: process).first?["response"]?["response"]?["updatedPermissions"] == nil)
        await runner.cancel()
    }

    @Test("a plan approval decision cannot answer an ordinary permission request")
    func invalidPlanApproval() async throws {
        let store = try makeTestStore("plan-invalid")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))
        await runner.answer(requestID: "req-1", decision: .approvePlan(mode: .bypassPermissions))
        #expect(answers(on: process).isEmpty)
        #expect(await runner.pendingAsks.count == 1)
        #expect(await runner.currentSession.permissionMode == .acceptEdits)
        await runner.cancel()
    }

    @Test("allowing writes an answer the CLI can act on and lets the turn run again")
    func allowing() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        await runner.answer(requestID: "req-1", decision: .allow(scope: .once))

        let answer = try #require(answers(on: process).first)
        #expect(answer["response"]?["request_id"]?.stringValue == "req-1")
        #expect(answer["response"]?["response"]?["behavior"]?.stringValue == "allow")

        #expect(await runner.pendingAsks.isEmpty)
        #expect(await runner.currentSession.state == .running)
        #expect(try await store.pendingPermissionAsks(sessionID: session.id).isEmpty)
        #expect(try await store.permissionAskDecisions(sessionID: session.id)["req-1"] == "allow-once")
    }

    @Test("denying carries the sentence the user typed")
    func denying() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        await runner.answer(requestID: "req-1", decision: .deny(message: "Not on my machine.", endsTurn: false))

        let answer = try #require(answers(on: process).first)
        #expect(answer["response"]?["response"]?["behavior"]?.stringValue == "deny")
        #expect(answer["response"]?["response"]?["message"]?.stringValue == "Not on my machine.")
        #expect(try await store.permissionAskDecisions(sessionID: session.id)["req-1"] == "deny")
    }

    @Test("a question can only be answered once")
    func answeredOnce() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        await runner.answer(requestID: "req-1", decision: .allow(scope: .once))
        await runner.answer(requestID: "req-1", decision: .deny(message: "no", endsTurn: false))

        #expect(answers(on: process).count == 1)
    }

    @Test("the session keeps waiting while any question is unanswered")
    func severalAtOnce() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, _) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask(id: "req-1", toolUse: "toolu_01")))
        await runner.ingest(.permissionAsk(ask(id: "req-2", toolUse: "toolu_02")))

        await runner.answer(requestID: "req-1", decision: .allow(scope: .once))
        #expect(await runner.currentSession.state == .waiting)

        await runner.answer(requestID: "req-2", decision: .allow(scope: .once))
        #expect(await runner.currentSession.state == .running)
    }

    @Test("always allow records a rule that outlives the session")
    func grantsAProjectRule() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, _) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        await runner.answer(requestID: "req-1", decision: .allow(scope: .project))

        let grants = try await store.permissionGrants(repoID: try await repoID(of: session, in: store))
        #expect(grants.map(\.displayText) == ["Bash(sudo -n true)"])
        #expect(grants.first?.grantedFor == "sudo -n true")
    }

    @Test("allowing once grants nothing")
    func onceGrantsNothing() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, _) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        await runner.answer(requestID: "req-1", decision: .allow(scope: .once))

        #expect(try await store.permissionGrants().isEmpty)
    }

    @Test("a chat with no workspace cannot grant a project rule, however it is answered")
    func noWorkspaceGrantsNothing() async throws {
        let store = try makeTestStore("perm")
        let session = try await store.upsert(AskConversation.newSession())
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        await runner.answer(requestID: "req-1", decision: .allow(scope: .project))

        #expect(try await store.permissionGrants().isEmpty)
        #expect(answers(on: process).count == 1)
    }

    @Test("a rule granted earlier answers without anybody being asked")
    func autoAllowed() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"),
            repoID: try await repoID(of: session, in: store)
        ))
        let (runner, process) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask()))

        #expect(answers(on: process).count == 1)
        #expect(await runner.pendingAsks.isEmpty)
        #expect(await runner.currentSession.state != .waiting)
        #expect(try await store.pendingPermissionAsks(sessionID: session.id).isEmpty)
    }

    @Test("an auto-allowed call says which rule allowed it")
    func autoAllowIsVisible() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"),
            repoID: try await repoID(of: session, in: store)
        ))
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )
        try await runner.send("go")

        let events = runner.events
        let watching = Task<String?, Never> {
            for await event in events {
                if case .permissionDecided(let resolution) = event { return resolution.note }
            }
            return nil
        }
        await runner.ingest(.permissionAsk(ask()))
        let note = await watching.value

        #expect(note?.contains("Bash(sudo -n true)") == true)
        #expect(try await store.permissionAskDecisions(sessionID: session.id)["req-1"]
            == PermissionAskOutcome.auto)
    }

    @Test("the question always reaches a view before the answer to it does")
    func askArrivesBeforeItsDecision() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"),
            repoID: try await repoID(of: session, in: store)
        ))
        let recorder = ProcessRecorder()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store, makeProcess: recorder.factory
        )
        try await runner.send("go")

        let events = runner.events
        let watching = Task<[String], Never> {
            var seen: [String] = []
            for await event in events {
                switch event {
                case .permissionAsk: seen.append("ask")
                case .permissionDecided:
                    seen.append("decided")
                    return seen
                default: break
                }
            }
            return seen
        }
        await runner.ingest(.permissionAsk(ask()))

        #expect(await watching.value == ["ask", "decided"])
    }

    @Test("a person answering during the rule lookup is not overtaken by it")
    func answerRacesTheLookup() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"),
            repoID: try await repoID(of: session, in: store)
        ))
        let (runner, process) = try await running(store, session: session)

        async let arriving: Void = runner.ingest(.permissionAsk(ask()))
        async let answering: Void = runner.answer(requestID: "req-1", decision: .deny(message: "no", endsTurn: false))
        _ = await (arriving, answering)

        #expect(answers(on: process).count == 1)
        #expect(await runner.pendingAsks.isEmpty)
        #expect(await runner.currentSession.state != .waiting)
    }

    @Test("using a rule is counted, so the list can say whether it earns its place")
    func countsUses() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let repo = try await repoID(of: session, in: store)
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"), repoID: repo
        ))
        let (runner, _) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask(id: "req-1", toolUse: "toolu_01")))
        await runner.ingest(.permissionAsk(ask(id: "req-2", toolUse: "toolu_02")))

        #expect(try await store.permissionGrants(repoID: repo).first?.useCount == 2)
    }

    @Test("a revoked rule stops answering immediately")
    func revocationBites() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let repo = try await repoID(of: session, in: store)
        let grant = try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"), repoID: repo
        ))
        let (runner, _) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask(id: "req-1", toolUse: "toolu_01")))
        #expect(await runner.currentSession.state != .waiting)

        try await store.deletePermissionGrant(id: grant.id)
        await runner.ingest(.permissionAsk(ask(id: "req-2", toolUse: "toolu_02")))

        #expect(await runner.currentSession.state == .waiting)
        #expect(await runner.pendingAsks.map(\.requestID) == ["req-2"])
    }

    @Test("another project's rule does not answer this one")
    func grantsDoNotLeakAcrossProjects() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let other = try await store.upsert(Repo(name: "other", path: "/tmp/other-\(newID())"))
        try await store.upsert(PermissionGrant.granting(
            PermissionRule(toolName: "Bash", ruleContent: "sudo -n true"), repoID: other.id
        ))
        let (runner, _) = try await running(store, session: session)

        await runner.ingest(.permissionAsk(ask()))

        #expect(await runner.currentSession.state == .waiting)
    }

    @Test("stopping denies every open question in words before the pipe closes")
    func stopDenies() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask(id: "req-1", toolUse: "toolu_01")))
        await runner.ingest(.permissionAsk(ask(id: "req-2", toolUse: "toolu_02")))

        await runner.cancel()

        let written = answers(on: process)
        #expect(written.count == 2)
        for answer in written {
            #expect(answer["response"]?["response"]?["behavior"]?.stringValue == "deny")
            #expect(answer["response"]?["response"]?["interrupt"]?.boolValue == true)
            #expect(answer["response"]?["response"]?["message"]?.stringValue?.isEmpty == false)
        }
    }

    @Test("Stop from a button answers the question before it signals the process")
    func cancelNowDeniesFirst() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        runner.cancelNow()

        let answer = try #require(answers(on: process).first)
        #expect(answer["response"]?["response"]?["behavior"]?.stringValue == "deny")
        #expect(answer["response"]?["response"]?["message"]?.stringValue
            == PermissionDecision.stoppedMessage)
        #expect(process.wasTerminated)
    }

    @Test("quitting denies in words too, and says it was Unified Dev that did it")
    func quitDenies() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        runner.denyPendingAsks(PermissionDecision.quittingMessage)

        let answer = try #require(answers(on: process).first)
        #expect(answer["response"]?["response"]?["message"]?.stringValue
            == PermissionDecision.quittingMessage)
        #expect(await runner.pendingAsks.isEmpty)
    }

    @Test("denying twice on the way out writes one answer per question")
    func denyingIsIdempotent() async throws {
        let store = try makeTestStore("perm")
        let session = try await makeSession(store)
        let (runner, process) = try await running(store, session: session)
        await runner.ingest(.permissionAsk(ask()))

        runner.denyPendingAsks(PermissionDecision.quittingMessage)
        runner.denyPendingAsks(PermissionDecision.quittingMessage)

        #expect(answers(on: process).count == 1)
    }
}

@Suite("Side conversation Claude transport", .scratchDirectory)
struct SideConversationClaudeRunnerTests {
    @Test func contextUsesStdinAndNeverResumesTheParent() async throws {
        let store = try makeTestStore("side-claude-wire")
        let createdParent = try await makeSession(store)
        let parent = try #require(try await store.session(id: createdParent.id))
        let child = try await store.openSideConversation(parentID: parent.id, streamingText: "Original context")
        let recorder = ProcessRecorder()
        let runner = AgentRunner(workspacePath: "/tmp/w", session: child, store: store, makeProcess: recorder.factory)
        try await runner.send("Why?")
        let process = try #require(recorder.last)
        #expect(!process.launch.arguments.contains("--resume"))
        #expect(!process.launch.arguments.joined().contains("Original context"))
        #expect(process.stdin.first?.contains("Original context") == true)
        let messages = try await store.messages(sessionID: child.id)
        let question = try #require(messages.first(where: { $0.kind == .user }))
        #expect(UserTurnPrompt.text(in: question.payload) == "Why?")
        process.emit(#"{"type":"assistant","message":{"content":[{"type":"text","text":"Because it preserves ordering"}]}}"#)
        await waitUntil("context acknowledged") {
            (try? await store.setting(SideConversation.contextDeliveredKey(child.id))) == "1"
        }
        try await runner.send("And the tests?")
        #expect(process.stdin.last?.contains("Original context") == false)
        #expect(try await store.session(id: parent.id) == parent)
        await runner.cancel()
    }
}
