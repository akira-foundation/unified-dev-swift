import Foundation

public enum ClaudeResolvedModel {
    private static let settingPrefix = "claude.resolved-model"
    private static let probedPrefix = "claude.probed-model"
    private static let firstDatedNumber = 100

    public static func version(
        ofAlias alias: String,
        listed: [AgentModel],
        reported: [String: String]
    ) -> String? {
        if let current = reported[alias].flatMap({ parsed($0, alias: alias) }) { return label(current) }
        let listedVersions = listed.filter { $0.unavailable == nil }.compactMap { parsed($0.id, alias: alias) }
        return listedVersions.max { $1.isAbove($0) }.map(label)
    }

    static func preferred(probed: [String: String], observed: [String: String]) -> [String: String] {
        observed.merging(probed) { _, probed in probed }
    }

    static func version(of id: String, alias: String) -> String? {
        parsed(id, alias: alias).map(label)
    }

    private static func parsed(_ id: String, alias: String) -> ClaudeModelRank.Version? {
        guard id.hasPrefix("claude-"),
              let family = ClaudeModelRank.families.firstIndex(of: alias),
              var version = ClaudeModelRank.version(after: family, in: ClaudeModelRank.tokens(of: id)),
              version.major < firstDatedNumber else { return nil }
        if version.minor >= firstDatedNumber { version.minor = 0 }
        return version
    }

    private static func label(_ version: ClaudeModelRank.Version) -> String {
        version.minor > 0 ? "\(version.major).\(version.minor)" : "\(version.major)"
    }

    public static func record(
        requested alias: String,
        reported model: String,
        account: AgentAccountHome?,
        in store: Store
    ) async {
        guard version(of: model, alias: alias) != nil else { return }
        await write(model, key: settingKey(settingPrefix, alias: alias, account: accountID(account)), in: store)
    }

    static func recordProbed(_ models: [String: String], account: AgentAccountHome?, in store: Store) async {
        let id = accountID(account)
        for (alias, model) in models.sorted(by: { $0.key < $1.key }) where version(of: model, alias: alias) != nil {
            await write(model, key: settingKey(probedPrefix, alias: alias, account: id), in: store)
        }
    }

    public static func reported(account: AgentAccountHome?, in store: Store) async -> [String: String] {
        preferred(probed: await probed(account: account, in: store), observed: await observed(account: account, in: store))
    }

    static func observed(account: AgentAccountHome?, in store: Store) async -> [String: String] {
        await read(settingPrefix, account: account, in: store)
    }

    static func probed(account: AgentAccountHome?, in store: Store) async -> [String: String] {
        await read(probedPrefix, account: account, in: store)
    }

    static func settingKeys(account: AgentAccountID) -> [String] {
        [settingPrefix, probedPrefix].flatMap { prefix in
            ClaudeModelCatalog.builtIn.map { settingKey(prefix, alias: $0.id, account: account) }
        }
    }

    private static func read(_ prefix: String, account: AgentAccountHome?, in store: Store) async -> [String: String] {
        let id = accountID(account)
        var models: [String: String] = [:]
        for alias in ClaudeModelCatalog.builtIn.map(\.id) {
            models[alias] = try? await store.setting(settingKey(prefix, alias: alias, account: id))
        }
        return models
    }

    private static func write(_ model: String, key: String, in store: Store) async {
        guard (try? await store.setting(key)) != model else { return }
        try? await store.setSetting(key, model)
    }

    private static func settingKey(_ prefix: String, alias: String, account: AgentAccountID) -> String {
        "\(prefix).\(account.rawValue).\(alias)"
    }

    static func accountID(_ account: AgentAccountHome?) -> AgentAccountID {
        account?.id ?? AgentAccountHome.defaultID(for: .claudeCode)
    }
}
