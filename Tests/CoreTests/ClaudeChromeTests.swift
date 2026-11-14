import Foundation
import Testing
@testable import Core

@Suite("ClaudeChrome", .tags(.agentProtocol))
struct ClaudeChromeTests {
    private let session = Session(workspaceID: WorkspaceID("w"), model: "opus")

    static func initLine(servers: String) -> String {
        #"{"type":"system","subtype":"init","session_id":"s","model":"opus","tools":["Bash"],"mcp_servers":["#
            + servers + "]}"
    }

    static let loaded = initLine(servers: #"{"name":"claude-in-chrome","status":"connected","source":"dynamic"}"#)
    static let absent = initLine(servers: #"{"name":"unifieddev-workspace-bridge","status":"connected"}"#)
    static let failed = initLine(servers: #"{"name":"claude-in-chrome","status":"failed"}"#)
    static let unstated = initLine(servers: #"{"name":"claude-in-chrome"}"#)

    private func initEvent(_ line: String) throws -> Data {
        guard case .initialized(let info) = try #require(AgentEvent.decode(line: line)) else {
            Issue.record("not an init event")
            return Data()
        }
        return info.raw
    }

    @Test("switched off, the argument list is the one Claude Code had before the switch existed")
    func offLeavesArgvAlone() {
        let before = AgentRunner.argv(session: session, resume: "r", mcpConfigPath: "/tmp/m.json")
        let off = AgentRunner.argv(session: session, resume: "r", mcpConfigPath: "/tmp/m.json", chrome: false)
        #expect(off == before)
        #expect(!off.contains("--chrome"))
        #expect(!off.contains("--no-chrome"))
    }

    @Test("switched on, --chrome is passed once and nothing else moves")
    func onAddsTheFlag() {
        let off = AgentRunner.argv(session: session, resume: nil, mcpConfigPath: "/tmp/m.json")
        let on = AgentRunner.argv(session: session, resume: nil, mcpConfigPath: "/tmp/m.json", chrome: true)
        #expect(on.filter { $0 == "--chrome" }.count == 1)
        #expect(on.filter { $0 != "--chrome" } == off)
    }

    @Test("the stored setting reads as on only when it says so", arguments: [
        ("1", true), ("0", false), ("", false), ("true", false),
    ])
    func storedSetting(stored: String, expected: Bool) {
        #expect(ClaudeChrome.isEnabled(stored) == expected)
    }

    @Test("no stored setting is off, and switching off clears the row")
    func defaultIsOff() {
        #expect(!ClaudeChrome.isEnabled(nil))
        #expect(ClaudeChrome.storedValue(false) == nil)
        #expect(ClaudeChrome.isEnabled(ClaudeChrome.storedValue(true)))
    }

    @Test("a notice is owed only when Chrome was asked for and did not connect")
    func noticeOwed() throws {
        #expect(ClaudeChromeNotice.missing(requested: true, initEvent: try initEvent(Self.loaded)) == nil)
        #expect(ClaudeChromeNotice.missing(requested: false, initEvent: try initEvent(Self.absent)) == nil)
        #expect(ClaudeChromeNotice.missing(requested: false, initEvent: try initEvent(Self.failed)) == nil)
        #expect(ClaudeChromeNotice.missing(requested: true, initEvent: try initEvent(Self.absent)) == ClaudeChromeNotice(status: nil))
        #expect(ClaudeChromeNotice.missing(requested: true, initEvent: try initEvent(Self.failed)) == ClaudeChromeNotice(status: "failed"))
        #expect(ClaudeChromeNotice.missing(requested: true, initEvent: try initEvent(Self.unstated)) == ClaudeChromeNotice(status: "unknown"))
    }

    @Test("the notice survives being stored and says why the tools are missing")
    func noticeRoundTrip() throws {
        let absent = ClaudeChromeNotice(status: nil)
        let failed = ClaudeChromeNotice(status: "failed")
        #expect(ClaudeChromeNotice.decode(absent.payload) == absent)
        #expect(ClaudeChromeNotice.decode(failed.payload) == failed)
        #expect(absent.sentence.contains("claude.ai sign in"))
        #expect(failed.sentence.contains("(failed)"))
        #expect(ClaudeChromeNotice.decode(Data(#"{"type":"rate_limit_event"}"#.utf8)) == nil)
    }
}

@Suite("ClaudeChrome runner", .tags(.agentProtocol), .scratchDirectory, .timeLimit(.minutes(1)))
struct ClaudeChromeRunnerTests {
    private func makeSession(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r-\(UUID().uuidString)"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/w", baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, model: "opus"))
    }

    private func runner(chrome: String?, label: String) async throws -> (AgentRunner, LaunchLog, Store, Session) {
        let store = try makeTestStore(label)
        try await store.setSetting(ClaudeChrome.settingKey, chrome)
        let session = try await makeSession(store)
        let log = LaunchLog()
        let runner = AgentRunner(
            workspacePath: "/tmp/w", session: session, store: store,
            segmentID: try await activeSegmentID(store, session), makeProcess: log.factory
        )
        try? await runner.send("hello")
        return (runner, log, store, session)
    }

    private func notices(_ store: Store, _ session: Session) async throws -> [ClaudeChromeNotice] {
        try await store.messages(sessionID: session.id)
            .filter { $0.kind == .notice }
            .compactMap { ClaudeChromeNotice.decode($0.payload) }
    }

    private func ingestInit(_ line: String, into runner: AgentRunner) async throws {
        await runner.ingest(try #require(AgentEvent.decode(line: line)))
    }

    @Test("the stored switch reaches the launched process")
    func switchReachesTheLaunch() async throws {
        let (_, onLog, _, _) = try await runner(chrome: "1", label: "chrome-on")
        let (_, offLog, _, _) = try await runner(chrome: nil, label: "chrome-off")
        #expect(try #require(onLog.first).arguments.contains("--chrome"))
        #expect(!(try #require(offLog.first).arguments.contains("--chrome")))
    }

    @Test("asked for and missing, the chat is told once")
    func missingIsToldOnce() async throws {
        let (runner, _, store, session) = try await runner(chrome: "1", label: "chrome-missing")
        try await ingestInit(ClaudeChromeTests.absent, into: runner)
        try await ingestInit(ClaudeChromeTests.absent, into: runner)
        #expect(try await notices(store, session) == [ClaudeChromeNotice(status: nil)])
    }

    @Test("loaded, or never asked for, the chat is told nothing")
    func nothingToTell() async throws {
        let (onRunner, _, onStore, onSession) = try await runner(chrome: "1", label: "chrome-loaded")
        try await ingestInit(ClaudeChromeTests.loaded, into: onRunner)
        #expect(try await notices(onStore, onSession).isEmpty)

        let (offRunner, _, offStore, offSession) = try await runner(chrome: nil, label: "chrome-unasked")
        try await ingestInit(ClaudeChromeTests.absent, into: offRunner)
        #expect(try await notices(offStore, offSession).isEmpty)
    }
}
