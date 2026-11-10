import Foundation
import Testing
@testable import Core

@Suite("Asking the installed Claude Code what each alias resolves to, without a turn", .tags(.agentProtocol), .scratchDirectory)
struct ClaudeAliasProbeTests {
    private var work: AgentAccountHome { probeAccount() }

    @Test("the launch keeps the account's login, reads none of its settings files, and turns off hooks, servers, memory and the saved session")
    func launchesQuietly() throws {
        let arguments = ClaudeAliasProbe.arguments(alias: "opus", baseURL: "http://127.0.0.1:9", proxy: "http://127.0.0.1:8")

        #expect(arguments.starts(with: ["-p", "."]))
        let sources = try #require(arguments.firstIndex(of: "--setting-sources"))
        #expect(arguments[sources + 1] == "local")
        #expect(probedAlias(of: AgentLaunch(executable: "", arguments: arguments, cwd: "", environment: [:])) == "opus")
        #expect(arguments.contains("--strict-mcp-config"))
        #expect(arguments.contains("--no-session-persistence"))
        #expect(arguments.contains("--disable-slash-commands"))
        #expect(!arguments.contains("--bare"))

        let index = try #require(arguments.firstIndex(of: "--settings"))
        let settings = try #require(JSONValue.parse(arguments[index + 1]))
        #expect(settings["disableAllHooks"]?.boolValue == true)
        #expect(settings["autoMemoryEnabled"]?.boolValue == false)
        #expect(settings["env"]?["ANTHROPIC_BASE_URL"]?.stringValue == "http://127.0.0.1:9")
        for variable in ClaudeAliasProbe.proxyVariables {
            #expect(settings["env"]?[variable]?.stringValue == "http://127.0.0.1:8")
        }
    }

    @Test("the address and the provider switches outrank the account's settings file and the inherited environment")
    func neverReachesARealServer() async throws {
        let launches = ProbeLaunches()
        let inherited = [
            "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
            "CLAUDE_CODE_USE_BEDROCK": "1",
            "CLAUDE_CODE_USE_VERTEX": "1",
            "HTTPS_PROXY": "http://proxy.example:8080",
            "http_proxy": "http://proxy.example:8080",
            "PATH": "/usr/bin",
        ]
        _ = await scriptedProbe(launches, inherited: inherited) { _ in [probeInitLine("claude-opus-5-5")] }
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
        let proxy = try #require(launched["HTTPS_PROXY"])
        #expect(proxy.hasPrefix("http://127.0.0.1:"))
        #expect(proxy != address)
        for variable in ClaudeAliasProbe.proxyVariables {
            #expect(launched[variable] == proxy)
            #expect(env[variable]?.stringValue == proxy)
        }
        #expect(launched["NO_PROXY"] == "127.0.0.1,localhost")
        #expect(env["ANTHROPIC_BASE_URL"]?.stringValue == address)
        #expect(launched["CLAUDE_CONFIG_DIR"] == work.directory.path)
        #expect(launched["PATH"] == "/usr/bin")
    }

    @Test("only the init event names the model the alias resolved to")
    func readsTheInitEvent() {
        #expect(ClaudeAliasProbe.initModel(in: probeInitLine("claude-opus-5-5")) == "claude-opus-5-5")
        #expect(ClaudeAliasProbe.initModel(in: #"{"type":"system","subtype":"hook_started"}"#) == nil)
        #expect(ClaudeAliasProbe.initModel(in: #"{"type":"assistant","message":{"model":"<synthetic>"}}"#) == nil)
        #expect(ClaudeAliasProbe.initModel(in: #"{"type":"system","subtype":"init","model":""}"#) == nil)
        #expect(ClaudeAliasProbe.initModel(in: "Warning: something") == nil)
    }

    @Test("every alias is asked in turn, answered from its init, and each process is ended once it has answered")
    func resolvesEveryAlias() async {
        let launches = ProbeLaunches()
        let resolved = await scriptedProbe(launches) { alias in
            [#"{"type":"system","subtype":"hook_started"}"#, probeInitLine("claude-\(alias)-5-5"), probeInitLine("claude-wrong")]
        }.resolve(["opus", "sonnet"], account: work)

        #expect(resolved.probed == ["opus": "claude-opus-5-5", "sonnet": "claude-sonnet-5-5"])
        #expect(launches.launches.map(probedAlias(of:)) == ["opus", "sonnet"])
        #expect(launches.processes.map(\.terminationCount) == [1, 1])
        #expect(Set(launches.launches.map { $0.environment["ANTHROPIC_BASE_URL"] }).count == 1)
    }

    @Test("a CLI that never reports is given up on at the deadline and ended", .timeLimit(.minutes(1)))
    func givesUpAtTheDeadline() async {
        let launches = ProbeLaunches()
        let resolved = await scriptedProbe(launches, timeout: .milliseconds(50)) { _ in [] }.resolve(["opus"], account: work)

        #expect(resolved.all.isEmpty)
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

}

private let localAgentsEnabled = ProcessInfo.processInfo.environment["UD_LOCAL_AGENTS"] == "1"

@Suite("ClaudeAliasProbeLocal", .enabled(if: localAgentsEnabled), .tags(.subprocess))
struct ClaudeAliasProbeLocalTests {
    @Test("the installed Claude Code names a version of its own family for every built in alias")
    func resolvesEveryAliasOnThisMac() async {
        let aliases = ClaudeModelCatalog.builtIn.map(\.id)
        let resolved = await ClaudeAliasProbe.using(executableOverride: nil).resolve(aliases, account: nil)

        for alias in aliases {
            #expect(resolved.all[alias].flatMap { ClaudeResolvedModel.version(of: $0, alias: alias) } != nil)
        }
    }
}
