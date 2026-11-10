import Foundation

public actor ClaudeAliasRefresh {
    public static let shared = ClaudeAliasRefresh()

    private var refreshed: Set<AgentAccountID> = []
    private let probe: (@Sendable (Store) async -> ClaudeAliasProbe)?

    init(probe: (@Sendable (Store) async -> ClaudeAliasProbe)? = nil) {
        self.probe = probe
    }

    public func refresh(account: AgentAccountHome?, in store: Store) async {
        guard refreshed.insert(ClaudeResolvedModel.accountID(account)).inserted else { return }
        let chosen: ClaudeAliasProbe
        if let probe {
            chosen = await probe(store)
        } else {
            let overrides = await AgentCatalog.executablePathOverrides(in: store)
            chosen = ClaudeAliasProbe.using(executableOverride: overrides[.claudeCode])
        }
        let models = await chosen.resolve(ClaudeModelCatalog.builtIn.map(\.id), account: account)
        await ClaudeResolvedModel.recordProbed(models, account: account, in: store)
    }
}
