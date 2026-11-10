import Foundation

public enum ClaudeResolvedModel {
    private static let settingPrefix = "claude.resolved-model"
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
        await record([alias: model], account: account, in: store)
    }

    static func record(_ models: [String: String], account: AgentAccountHome?, in store: Store) async {
        let id = accountID(account)
        for (alias, model) in models.sorted(by: { $0.key < $1.key }) where version(of: model, alias: alias) != nil {
            let key = settingKey(alias: alias, account: id)
            guard (try? await store.setting(key)) != model else { continue }
            try? await store.setSetting(key, model)
        }
    }

    public static func reported(account: AgentAccountHome?, in store: Store) async -> [String: String] {
        let id = accountID(account)
        var models: [String: String] = [:]
        for alias in ClaudeModelCatalog.builtIn.map(\.id) {
            models[alias] = try? await store.setting(settingKey(alias: alias, account: id))
        }
        return models
    }

    static func settingKeys(account: AgentAccountID) -> [String] {
        ClaudeModelCatalog.builtIn.map { settingKey(alias: $0.id, account: account) }
    }

    private static func settingKey(alias: String, account: AgentAccountID) -> String {
        "\(settingPrefix).\(account.rawValue).\(alias)"
    }

    static func accountID(_ account: AgentAccountHome?) -> AgentAccountID {
        account?.id ?? AgentAccountHome.defaultID(for: .claudeCode)
    }
}
