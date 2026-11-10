import Foundation
import Synchronization
import Testing
@testable import Core

private final class ScriptedProbe: AgentProcessing, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<String, Error>.Continuation
    private let terminations = Mutex(0)

    let lines: AsyncThrowingStream<String, Error>
    let errorLines = AsyncStream<String> { $0.finish() }

    init(printing output: [String]) {
        var out: AsyncThrowingStream<String, Error>.Continuation!
        lines = AsyncThrowingStream(bufferingPolicy: .unbounded) { out = $0 }
        continuation = out
        for line in output { continuation.yield(line) }
    }

    var terminationCount: Int { terminations.withLock { $0 } }
    var isRunning: Bool { true }
    var exitStatus: Int32 { get async { 0 } }

    func writeLine(_ text: String) {}
    func closeStdin() {}
    func terminate() {
        terminations.withLock { $0 += 1 }
        continuation.finish()
    }
    func kill() { continuation.finish() }
}

private final class ProbeLaunches: @unchecked Sendable {
    private let state = Mutex<[(AgentLaunch, ScriptedProbe)]>([])

    var launches: [AgentLaunch] { state.withLock { $0.map(\.0) } }
    var processes: [ScriptedProbe] { state.withLock { $0.map(\.1) } }

    func record(_ launch: AgentLaunch, _ process: ScriptedProbe) {
        state.withLock { $0.append((launch, process)) }
    }
}

private func initLine(_ model: String) -> String {
    #"{"type":"system","subtype":"init","session_id":"s","cwd":"/tmp","model":"\#(model)"}"#
}

private func alias(of launch: AgentLaunch) -> String {
    guard let index = launch.arguments.firstIndex(of: "--model") else { return "" }
    return launch.arguments[index + 1]
}

private func probe(
    _ launches: ProbeLaunches,
    timeout: Duration = .seconds(5),
    inherited: [String: String] = [:],
    output: @escaping @Sendable (String) -> [String]
) -> ClaudeAliasProbe {
    ClaudeAliasProbe(
        executable: "claude", cwd: "/tmp", environment: inherited, timeout: timeout,
        makeProcess: { launch in
            let process = ScriptedProbe(printing: output(alias(of: launch)))
            launches.record(launch, process)
            return process
        }
    )
}

@Suite("Asking the installed Claude Code what each alias resolves to, without a turn", .tags(.agentProtocol), .scratchDirectory)
struct ClaudeAliasProbeTests {
    private let work = AgentAccountHome(
        provider: .claudeCode, id: AgentAccountID("work"),
        directory: URL(filePath: "/accounts/claudeCode/work"), isDefault: false
    )

    @Test("the launch keeps the account's own settings and turns off hooks, servers, memory and the saved session")
    func launchesQuietly() throws {
        let arguments = ClaudeAliasProbe.arguments(alias: "opus", baseURL: "http://127.0.0.1:9")

        #expect(arguments.starts(with: ["-p", "."]))
        #expect(alias(of: AgentLaunch(executable: "", arguments: arguments, cwd: "", environment: [:])) == "opus")
        #expect(arguments.contains("--strict-mcp-config"))
        #expect(arguments.contains("--no-session-persistence"))
        #expect(arguments.contains("--disable-slash-commands"))
        #expect(!arguments.contains("--bare"))
        #expect(!arguments.contains("--setting-sources"))

        let index = try #require(arguments.firstIndex(of: "--settings"))
        let settings = try #require(JSONValue.parse(arguments[index + 1]))
        #expect(settings["disableAllHooks"]?.boolValue == true)
        #expect(settings["autoMemoryEnabled"]?.boolValue == false)
        #expect(settings["env"]?["ANTHROPIC_BASE_URL"]?.stringValue == "http://127.0.0.1:9")
    }

    @Test("the address and the provider switches outrank the account's settings file and the inherited environment")
    func neverReachesARealServer() async throws {
        let launches = ProbeLaunches()
        let inherited = [
            "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
            "CLAUDE_CODE_USE_BEDROCK": "1",
            "CLAUDE_CODE_USE_VERTEX": "1",
            "PATH": "/usr/bin",
        ]
        _ = await probe(launches, inherited: inherited) { _ in [initLine("claude-opus-5-5")] }
            .resolve(["opus"], account: work)
        let launch = try #require(launches.launches.first)
        let launched = launch.environment
        let index = try #require(launch.arguments.firstIndex(of: "--settings"))
        let env = try #require(JSONValue.parse(launch.arguments[index + 1])?["env"])
        let address = try #require(launched["ANTHROPIC_BASE_URL"])

        for variable in ["CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"] {
            #expect(env[variable]?.stringValue == "0")
            #expect(launched[variable] == "0")
        }
        #expect(address.hasPrefix("http://127.0.0.1:"))
        #expect(env["ANTHROPIC_BASE_URL"]?.stringValue == address)
        #expect(launched["CLAUDE_CONFIG_DIR"] == work.directory.path)
        #expect(launched["PATH"] == "/usr/bin")
    }

    @Test("only the init event names the model the alias resolved to")
    func readsTheInitEvent() {
        #expect(ClaudeAliasProbe.initModel(in: initLine("claude-opus-5-5")) == "claude-opus-5-5")
        #expect(ClaudeAliasProbe.initModel(in: #"{"type":"system","subtype":"hook_started"}"#) == nil)
        #expect(ClaudeAliasProbe.initModel(in: #"{"type":"assistant","message":{"model":"<synthetic>"}}"#) == nil)
        #expect(ClaudeAliasProbe.initModel(in: #"{"type":"system","subtype":"init","model":""}"#) == nil)
        #expect(ClaudeAliasProbe.initModel(in: "Warning: something") == nil)
    }

    @Test("every alias is asked at once, answered from its init, and each process is ended once it has answered")
    func resolvesEveryAlias() async {
        let launches = ProbeLaunches()
        let resolved = await probe(launches) { alias in
            [#"{"type":"system","subtype":"hook_started"}"#, initLine("claude-\(alias)-5-5"), initLine("claude-wrong")]
        }.resolve(["opus", "sonnet"], account: work)

        #expect(resolved == ["opus": "claude-opus-5-5", "sonnet": "claude-sonnet-5-5"])
        #expect(launches.processes.map(\.terminationCount) == [1, 1])
        #expect(Set(launches.launches.map { $0.environment["ANTHROPIC_BASE_URL"] }).count == 1)
    }

    @Test("a CLI that never reports is given up on at the deadline and ended")
    func givesUpAtTheDeadline() async {
        let launches = ProbeLaunches()
        let resolved = await probe(launches, timeout: .milliseconds(50)) { _ in [] }.resolve(["opus"], account: nil)

        #expect(resolved.isEmpty)
        #expect(launches.processes.map(\.terminationCount) == [1])
    }

    @Test("the address the CLI is sent to accepts a connection on this Mac and answers nothing")
    func theEndpointNeverAnswers() throws {
        let endpoint = try #require(UnansweredEndpoint())
        let client = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(client) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = endpoint.port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(client, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        var wait = timeval(tv_sec: 0, tv_usec: 100_000)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        var byte: UInt8 = 0
        let received = recv(client, &byte, 1, 0)

        #expect(connected == 0)
        #expect(endpoint.url == "http://127.0.0.1:\(endpoint.port)")
        #expect(received == -1)
    }

    @Test("an account is probed once per launch of the app, and what it answered is kept for it")
    func probesAnAccountOnce() async throws {
        let store = try makeTestStore("probe")
        let launches = ProbeLaunches()
        let refresh = ClaudeAliasRefresh(probe: { _ in
            probe(launches) { alias in [initLine("claude-\(alias)-5-5")] }
        })

        await refresh.refresh(account: work, in: store)
        await refresh.refresh(account: work, in: store)

        #expect(launches.launches.count == ClaudeModelCatalog.builtIn.count)
        #expect(await ClaudeResolvedModel.reported(account: work, in: store) == [
            "fable": "claude-fable-5-5", "opus": "claude-opus-5-5",
            "sonnet": "claude-sonnet-5-5", "haiku": "claude-haiku-5-5",
        ])
        #expect(await ClaudeResolvedModel.reported(account: nil, in: store).isEmpty)
    }
}

private let localAgentsEnabled = ProcessInfo.processInfo.environment["UD_LOCAL_AGENTS"] == "1"

@Suite("ClaudeAliasProbeLocal", .enabled(if: localAgentsEnabled), .tags(.subprocess))
struct ClaudeAliasProbeLocalTests {
    @Test("the installed Claude Code names a version of its own family for every built in alias")
    func resolvesEveryAliasOnThisMac() async {
        let aliases = ClaudeModelCatalog.builtIn.map(\.id)
        let resolved = await ClaudeAliasProbe.using(executableOverride: nil).resolve(aliases, account: nil)

        for alias in aliases {
            #expect(resolved[alias].flatMap { ClaudeResolvedModel.version(of: $0, alias: alias) } != nil)
        }
    }
}
