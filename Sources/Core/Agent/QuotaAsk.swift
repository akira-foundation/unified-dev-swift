import Foundation

public enum QuotaPollSchedule {
    public static let interval: TimeInterval = 60

    public static let onDemandFloor: TimeInterval = 30

    public static func isDue(lastAskedAt: Date?, at now: Date, after gap: TimeInterval) -> Bool {
        guard let lastAskedAt else { return true }
        return now.timeIntervalSince(lastAskedAt) >= gap
    }
}

public protocol AgentQuotaSource: Sendable {
    static var provider: AgentKind { get }

    func read() async -> Data?
}

public struct ClaudeCodeQuotaSource: AgentQuotaSource {
    public static let provider = AgentKind.claudeCode

    public static let arguments = [
        "-p",
        "--output-format", "stream-json",
        "--input-format", "stream-json",
        "--verbose",
    ]

    public static func request(id: String) -> String {
        let json = JSONValue.object([
            "type": .string("control_request"),
            "request_id": .string(id),
            "request": .object(["subtype": .string("get_usage")]),
        ])
        return encode(json)
    }

    static func encode(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    public static func answer(in line: String, to id: String) -> Data? {
        guard let json = JSONValue.parse(Data(line.utf8)),
              json["type"]?.stringValue == "control_response",
              let response = json["response"],
              response["request_id"]?.stringValue == id,
              response["subtype"]?.stringValue == "success",
              let payload = response["response"]
        else { return nil }
        return (try? JSONEncoder().encode(payload))
    }

    private let executable: String
    private let cwd: String
    private let environment: [String: String]
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    public init(
        executable: String = AgentRunner.executable,
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String] = Shell.environment(),
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = AgentRunner.spawn
    ) {
        self.executable = executable
        self.cwd = cwd
        self.environment = environment
        self.makeProcess = makeProcess
    }

    public func read() async -> Data? {
        let id = "unifieddev-usage-\(UUID().uuidString)"
        let process = makeProcess(AgentLaunch(
            executable: executable,
            arguments: Self.arguments,
            cwd: cwd,
            environment: environment
        ))
        let lines = process.lines
        process.writeLine(Self.request(id: id))

        var answer: Data?
        do {
            for try await line in lines {
                if let payload = Self.answer(in: line, to: id) {
                    answer = payload
                    break
                }
            }
        } catch {
            answer = nil
        }
        process.terminate()
        return answer
    }
}

public struct CodexQuotaSource: AgentQuotaSource {
    public static let provider = AgentKind.codex

    public static let method = "account/rateLimits/read"

    private let configuration: CodexClient.Configuration
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    public init(
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String] = Shell.environment(),
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = CodexClient.spawn
    ) {
        configuration = CodexClient.Configuration(cwd: cwd, environment: environment)
        self.makeProcess = makeProcess
    }

    public func read() async -> Data? {
        let client = CodexClient(configuration: configuration, makeProcess: makeProcess)
        defer { Task { await client.stop() } }
        do {
            try await client.start()
            let result = try await client.send(Self.method, params: nil)
            return try JSONEncoder().encode(result)
        } catch {
            return nil
        }
    }
}

public enum AgentQuotaSources {
    public static func all() -> [any AgentQuotaSource] {
        [ClaudeCodeQuotaSource(), CodexQuotaSource()]
    }

    public static func readAll(
        _ sources: [any AgentQuotaSource] = AgentQuotaSources.all(),
        at now: Date = Date()
    ) async -> [AgentQuota] {
        await report(sources, at: now).quotas
    }

    public static func report(
        _ sources: [any AgentQuotaSource] = AgentQuotaSources.all(),
        at now: Date = Date()
    ) async -> QuotaReport {
        await withTaskGroup(of: QuotaReport.self) { group in
            for source in sources {
                group.addTask {
                    guard let payload = await source.read() else {
                        return QuotaReport(unanswered: [type(of: source).provider])
                    }
                    return QuotaReport(
                        quotas: AgentQuotaAdapters.quotas(fromRateLimitEvent: payload, at: now),
                        accounts: AgentAccountReader.account(from: payload, at: now).map { [$0] } ?? []
                    )
                }
            }
            return await group.reduce(into: QuotaReport()) { total, next in
                total.quotas += next.quotas
                total.accounts += next.accounts
                total.unanswered += next.unanswered
            }
        }
    }
}

public struct QuotaReport: Sendable {
    public var quotas: [AgentQuota]
    public var accounts: [AgentAccount]
    public var unanswered: [AgentKind]

    public init(quotas: [AgentQuota] = [], accounts: [AgentAccount] = [], unanswered: [AgentKind] = []) {
        self.quotas = quotas
        self.accounts = accounts
        self.unanswered = unanswered
    }
}
