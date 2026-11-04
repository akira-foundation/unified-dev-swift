import Foundation

public struct GrokQuotaSource: AgentQuotaSource {
    public static let provider = AgentKind.grok

    public static let method = "_x.ai/billing"

    private let executable: String
    private let cwd: String
    private let environment: [String: String]?
    private let account: AgentAccountHome?
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    public init(
        executable: String = GrokClient.executable,
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String]? = nil,
        account: AgentAccountHome? = nil,
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = GrokClient.spawn
    ) {
        self.executable = executable
        self.cwd = cwd
        self.environment = environment
        self.account = account
        self.makeProcess = makeProcess
    }

    public func standing() async -> QuotaStanding {
        await LoginShellPath.ready()
        return QuotaStanding(isInstalled: Shell.which(executable) != nil)
    }

    public func read() async -> Data? {
        await LoginShellPath.ready()
        let configuration = GrokClient.Configuration(
            executable: executable,
            cwd: cwd,
            account: account,
            environment: environment ?? Shell.environment()
        )
        let client = GrokClient(configuration: configuration, makeProcess: makeProcess)
        defer { Task { await client.stop() } }
        do {
            try await client.start()
            let result = try await client.send(Self.method, params: .object([:]))
            return try JSONEncoder().encode(result)
        } catch {
            return nil
        }
    }

    public func account(from payload: Data, at now: Date) -> AgentAccount? {
        guard let line = JSONValue.parse(payload), GrokQuotaAdapter.config(in: line) != nil else { return nil }
        let tier = line["subscription_tier"]?.stringValue?.trimmingCharacters(in: .whitespaces)
        return AgentAccount(provider: Self.provider, plan: tier?.isEmpty == false ? tier : nil, observedAt: now)
    }
}

public enum GrokQuotaAdapter: AgentQuotaAdapter {
    public static let provider = AgentKind.grok

    static let periodPrefix = "USAGE_PERIOD_TYPE_"

    static func config(in line: JSONValue) -> JSONValue? {
        guard let config = line["config"], config["creditUsagePercent"] != nil else { return nil }
        return config
    }

    public static func quotas(from line: JSONValue, at now: Date) -> [AgentQuota] {
        guard let config = config(in: line) else { return [] }
        let period = config["currentPeriod"]
        let start = (period?["start"] ?? config["billingPeriodStart"])?.stringValue
            .flatMap(ClaudeCodeUsageAdapter.date(fromISO:))
        let end = (period?["end"] ?? config["billingPeriodEnd"])?.stringValue
            .flatMap(ClaudeCodeUsageAdapter.date(fromISO:))
        let measure: QuotaMeasure = config["creditUsagePercent"]?.doubleValue
            .map { .fraction($0 / 100) } ?? .unknown
        return [AgentQuota(
            provider: provider,
            window: window(named: period?["type"]?.stringValue, from: start, to: end),
            measure: measure,
            resetsAt: end,
            observedAt: now
        )]
    }

    static func window(named type: String?, from start: Date?, to end: Date?) -> QuotaWindow {
        var duration: TimeInterval?
        if let start, let end, end > start { duration = end.timeIntervalSince(start).rounded() }
        let name = type.map { $0.hasPrefix(periodPrefix) ? String($0.dropFirst(periodPrefix.count)) : $0 }?
            .lowercased()
        guard let name, !name.isEmpty else {
            return duration.map { QuotaWindow.lasting($0, key: "credits") }
                ?? QuotaWindow(key: "credits", label: "Credits")
        }
        return QuotaWindow(key: name, label: QuotaWindow.humanised(name), duration: duration)
    }
}
