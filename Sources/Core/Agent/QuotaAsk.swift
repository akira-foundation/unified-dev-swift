import Foundation

public enum QuotaPollSchedule {
    public static let interval: TimeInterval = 60

    public static let onDemandFloor: TimeInterval = 30

    public static func isDue(lastAskedAt: Date?, at now: Date, after gap: TimeInterval) -> Bool {
        guard let lastAskedAt else { return true }
        return now.timeIntervalSince(lastAskedAt) >= gap
    }
}

public struct QuotaStanding: Sendable, Equatable {
    public var isInstalled: Bool
    public var lastReportedAt: Date?

    public init(isInstalled: Bool, lastReportedAt: Date? = nil) {
        self.isInstalled = isInstalled
        self.lastReportedAt = lastReportedAt
    }
}

public protocol AgentQuotaSource: Sendable {
    static var provider: AgentKind { get }

    func read() async -> Data?

    func standing() async -> QuotaStanding
}

extension AgentQuotaSource {
    public func standing() async -> QuotaStanding { QuotaStanding(isInstalled: true) }
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
    private let environment: [String: String]?
    private let accountPath: String
    private let clock: @Sendable () -> Date
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    public init(
        executable: String = AgentRunner.executable,
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String]? = nil,
        accountPath: String = AgentCatalog.claudeAccountPath,
        clock: @escaping @Sendable () -> Date = Date.init,
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = AgentRunner.spawn
    ) {
        self.executable = executable
        self.cwd = cwd
        self.environment = environment
        self.accountPath = accountPath
        self.clock = clock
        self.makeProcess = makeProcess
    }

    public func standing() async -> QuotaStanding {
        await LoginShellPath.ready()
        return QuotaStanding(
            isInstalled: Shell.which(executable) != nil,
            lastReportedAt: ClaudeUsageCache.fetchedAt(in: account(), at: clock())
        )
    }

    public func read() async -> Data? {
        let answer = await ask()
        guard !ClaudeCodeUsageAdapter.carriesLimits(answer) else { return answer }
        guard let cached = ClaudeUsageCache.reading(from: account(), at: clock()) else { return answer }
        return Self.overlaid(answer, with: cached.payload) ?? cached.payload
    }

    static func overlaid(_ answer: Data?, with payload: Data) -> Data? {
        guard let answer,
              var fields = JSONValue.parse(answer)?.objectValue,
              let cached = JSONValue.parse(payload)?.objectValue
        else { return nil }
        for (key, value) in cached { fields[key] = value }
        return try? JSONEncoder().encode(JSONValue.object(fields))
    }

    private func account() -> Data? {
        FileManager.default.contents(atPath: accountPath)
    }

    private func ask() async -> Data? {
        let id = "unifieddev-usage-\(UUID().uuidString)"
        await LoginShellPath.ready()
        let process = makeProcess(AgentLaunch(
            executable: executable,
            arguments: Self.arguments,
            cwd: cwd,
            environment: environment ?? Shell.environment()
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

    private let executable: String
    private let cwd: String
    private let environment: [String: String]?
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    public init(
        executable: String = CodexClient.executable,
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String]? = nil,
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = CodexClient.spawn
    ) {
        self.executable = executable
        self.cwd = cwd
        self.environment = environment
        self.makeProcess = makeProcess
    }

    public func standing() async -> QuotaStanding {
        await LoginShellPath.ready()
        return QuotaStanding(isInstalled: Shell.which(executable) != nil)
    }

    public func read() async -> Data? {
        await LoginShellPath.ready()
        let configuration = CodexClient.Configuration(
            executable: executable,
            cwd: cwd,
            environment: environment ?? Shell.environment()
        )
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
                    let provider = type(of: source).provider
                    let standing = await source.standing()
                    guard standing.isInstalled else { return QuotaReport() }

                    var report = QuotaReport()
                    if let reportedAt = standing.lastReportedAt { report.lastReported[provider] = reportedAt }

                    guard let payload = await source.read() else {
                        report.unanswered = [provider]
                        return report
                    }
                    report.quotas = AgentQuotaAdapters.quotas(fromRateLimitEvent: payload, at: now)
                    report.accounts = AgentAccountReader.account(from: payload, at: now).map { [$0] } ?? []
                    return report
                }
            }
            return await group.reduce(into: QuotaReport()) { total, next in
                total.quotas += next.quotas
                total.accounts += next.accounts
                total.unanswered += next.unanswered
                total.lastReported.merge(next.lastReported) { _, later in later }
            }
        }
    }
}

public struct QuotaReport: Sendable {
    public var quotas: [AgentQuota]
    public var accounts: [AgentAccount]
    public var unanswered: [AgentKind]
    public var lastReported: [AgentKind: Date]

    public init(
        quotas: [AgentQuota] = [],
        accounts: [AgentAccount] = [],
        unanswered: [AgentKind] = [],
        lastReported: [AgentKind: Date] = [:]
    ) {
        self.quotas = quotas
        self.accounts = accounts
        self.unanswered = unanswered
        self.lastReported = lastReported
    }
}
