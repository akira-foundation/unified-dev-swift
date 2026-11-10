import Foundation

public actor ClaudeAliasRefresh {
    public static let shared = ClaudeAliasRefresh()
    public static let recheckInterval: Duration = .seconds(60)

    private static let unknownVersion = "unknown"

    private var answeredVersion: [AgentAccountID: String] = [:]
    private var checkedAt: [AgentAccountID: ContinuousClock.Instant] = [:]
    private var probing: Set<AgentAccountID> = []
    private let probe: (@Sendable (Store) async -> ClaudeAliasProbe)?
    private let installedVersion: (@Sendable (Store) async -> String?)?
    private let now: @Sendable () -> ContinuousClock.Instant

    init(
        probe: (@Sendable (Store) async -> ClaudeAliasProbe)? = nil,
        installedVersion: (@Sendable (Store) async -> String?)? = nil,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.probe = probe
        self.installedVersion = installedVersion
        self.now = now
    }

    public func refresh(account: AgentAccountHome?, in store: Store) async {
        let id = ClaudeResolvedModel.accountID(account)
        let moment = now()
        if let last = checkedAt[id], last.duration(to: moment) < Self.recheckInterval { return }
        guard probing.insert(id).inserted else { return }
        defer { probing.remove(id) }
        checkedAt[id] = moment
        let version = await version(in: store) ?? Self.unknownVersion
        guard answeredVersion[id] != version else { return }
        let models = await chosenProbe(in: store).resolve(ClaudeModelCatalog.builtIn.map(\.id), account: account)
        guard !models.isEmpty else { return }
        answeredVersion[id] = version
        await ClaudeResolvedModel.record(models, account: account, in: store)
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
