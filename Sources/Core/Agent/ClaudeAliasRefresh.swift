import Foundation

public actor ClaudeAliasRefresh {
    public static let shared = ClaudeAliasRefresh()
    static let recheckInterval: Duration = .seconds(60)
    static let retryInterval: Duration = .seconds(600)

    private static let unknownVersion = "unknown"

    private var answered: [AgentAccountID: (version: String, settings: String)] = [:]
    private var nextCheck: [AgentAccountID: ContinuousClock.Instant] = [:]
    private var probing: Set<AgentAccountID> = []
    private let probe: (@Sendable (Store) async -> ClaudeAliasProbe)?
    private let installedVersion: (@Sendable (Store) async -> String?)?
    private let now: @Sendable () -> ContinuousClock.Instant
    private let activity: ClaudeAccountActivity

    init(
        probe: (@Sendable (Store) async -> ClaudeAliasProbe)? = nil,
        installedVersion: (@Sendable (Store) async -> String?)? = nil,
        activity: ClaudeAccountActivity = .shared,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.probe = probe
        self.installedVersion = installedVersion
        self.activity = activity
        self.now = now
    }

    public func refresh(account: AgentAccountHome?, in store: Store) async {
        let id = ClaudeResolvedModel.accountID(account)
        let moment = now()
        if let next = nextCheck[id], moment < next { return }
        guard probing.insert(id).inserted else { return }
        defer { probing.remove(id) }
        nextCheck[id] = moment + Self.recheckInterval
        let version = await version(in: store)
        let aliases = ClaudeModelCatalog.builtIn.map(\.id)
        let probe = await chosenProbe(in: store)
        let settings = await probe.settingsFingerprint(aliases, account: account)
        if let last = answered[id], last.settings == settings {
            guard let version, version != last.version else { return }
        }
        guard !activity.isRunning(id) else { return }
        let answers = await probe.resolve(aliases, account: account)
        await ClaudeResolvedModel.record(answers, cliVersion: version, account: account, in: store)
        guard answers.all.count == aliases.count else {
            nextCheck[id] = moment + Self.retryInterval
            return
        }
        answered[id] = (version ?? Self.unknownVersion, settings)
    }

    private func version(in store: Store) async -> String? {
        if let installedVersion { return await installedVersion(store) }
        await LoginShellPath.ready()
        let overrides = await AgentCatalog.executablePathOverrides(in: store)
        let executable = AgentCatalog.executable(for: .claudeCode, override: overrides[.claudeCode])
        guard let path = Shell.which(executable) else { return nil }
        return await AgentCatalog.readVersion(executablePath: path)
    }

    private func chosenProbe(in store: Store) async -> ClaudeAliasProbe {
        if let probe { return await probe(store) }
        let overrides = await AgentCatalog.executablePathOverrides(in: store)
        return ClaudeAliasProbe.using(executableOverride: overrides[.claudeCode])
    }
}
