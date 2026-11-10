import Foundation

public struct ClaudeAliasProbe: Sendable {
    public static let timeout: Duration = .seconds(20)

    private let executable: String
    private let cwd: String
    private let environment: [String: String]?
    private let timeout: Duration
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    init(
        executable: String = AgentRunner.executable,
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String]? = nil,
        timeout: Duration = ClaudeAliasProbe.timeout,
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = AgentRunner.spawn
    ) {
        self.executable = executable
        self.cwd = cwd
        self.environment = environment
        self.timeout = timeout
        self.makeProcess = makeProcess
    }

    public static func using(executableOverride override: String?) -> ClaudeAliasProbe {
        ClaudeAliasProbe(executable: AgentCatalog.executable(for: .claudeCode, override: override))
    }

    public func resolve(_ aliases: [String], account: AgentAccountHome?) async -> [String: String] {
        guard let endpoint = UnansweredEndpoint() else { return [:] }
        await LoginShellPath.ready()
        let inherited = (environment ?? Shell.environment()).filter { !Self.proxyVariables.contains($0.key) }
        var found: [String: String] = [:]
        for alias in aliases {
            let launch = AgentLaunch(
                executable: executable,
                arguments: Self.arguments(alias: alias, baseURL: endpoint.url),
                cwd: cwd,
                environment: AgentAccountEnvironment.apply(account, to: inherited)
                    .merging(Self.overrides(baseURL: endpoint.url)) { _, override in override }
            )
            found[alias] = await reportedModel(launching: launch)
        }
        withExtendedLifetime(endpoint) {}
        return found
    }

    static let proxyVariables: Set<String> = [
        "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy",
    ]

    static func arguments(alias: String, baseURL: String) -> [String] {
        [
            "-p", ".",
            "--model", alias,
            "--output-format", "stream-json",
            "--verbose",
            "--setting-sources", "local",
            "--settings", settings(baseURL: baseURL),
            "--strict-mcp-config",
            "--no-session-persistence",
            "--disable-slash-commands",
        ]
    }

    static func overrides(baseURL: String) -> [String: String] {
        [
            "ANTHROPIC_BASE_URL": baseURL,
            "CLAUDE_CODE_USE_BEDROCK": "0",
            "CLAUDE_CODE_USE_VERTEX": "0",
            "CLAUDE_CODE_USE_FOUNDRY": "0",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
            "DISABLE_AUTOUPDATER": "1",
            "NO_PROXY": "127.0.0.1,localhost",
            "no_proxy": "127.0.0.1,localhost",
        ]
    }

    static func settings(baseURL: String) -> String {
        let value: [String: Any] = [
            "disableAllHooks": true,
            "autoMemoryEnabled": false,
            "env": overrides(baseURL: baseURL),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func initModel(in line: String) -> String? {
        guard let event = JSONValue.parse(line),
              event["type"]?.stringValue == "system",
              event["subtype"]?.stringValue == "init",
              let model = event["model"]?.stringValue, !model.isEmpty else { return nil }
        return model
    }

    private func reportedModel(launching launch: AgentLaunch) async -> String? {
        let process = makeProcess(launch)
        let lines = process.lines
        process.closeStdin()
        let model = await Self.first(within: timeout) { await Self.firstInitModel(in: lines) }
        process.terminate()
        let exited = await Self.first(within: .seconds(2)) { _ = await process.exitStatus; return true }
        if exited == nil { process.kill() }
        return model
    }

    private static func first<Answer: Sendable>(
        within deadline: Duration,
        _ work: @escaping @Sendable () async -> Answer?
    ) async -> Answer? {
        await withTaskGroup(of: Answer?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: deadline)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first.flatMap(\.self)
        }
    }

    private static func firstInitModel(in lines: AsyncThrowingStream<String, Error>) async -> String? {
        do {
            for try await line in lines {
                if let model = initModel(in: line) { return model }
            }
        } catch {
            return nil
        }
        return nil
    }
}
