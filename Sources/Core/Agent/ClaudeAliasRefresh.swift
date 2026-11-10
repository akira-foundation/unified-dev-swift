import Foundation

public actor ClaudeAliasRefresh {
    public static let shared = ClaudeAliasRefresh()

    private var answered: Set<AgentAccountID> = []
    private var probing: Set<AgentAccountID> = []
    private let probe: (@Sendable (Store) async -> ClaudeAliasProbe)?

    init(probe: (@Sendable (Store) async -> ClaudeAliasProbe)? = nil) {
        self.probe = probe
    }

    public func refresh(account: AgentAccountHome?, in store: Store) async {
        let id = ClaudeResolvedModel.accountID(account)
        guard !answered.contains(id), probing.insert(id).inserted else { return }
        defer { probing.remove(id) }
        let chosen: ClaudeAliasProbe
        if let probe {
            chosen = await probe(store)
        } else {
            let overrides = await AgentCatalog.executablePathOverrides(in: store)
            chosen = ClaudeAliasProbe.using(executableOverride: overrides[.claudeCode])
        }
        let models = await chosen.resolve(ClaudeModelCatalog.builtIn.map(\.id), account: account)
        guard !models.isEmpty else { return }
        answered.insert(id)
        await ClaudeResolvedModel.record(models, account: account, in: store)
    }
}
