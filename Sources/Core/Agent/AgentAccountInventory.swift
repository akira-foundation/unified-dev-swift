import Foundation

public enum AgentAccountInventory {
    public static func standings(
        rows: [AgentAccountRow],
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes(),
        report: @escaping @Sendable (AgentAccountHome) async -> AgentAccountLiveness.CliReport
    ) async -> [AgentAccountStanding] {
        await AgentAccountRoster.standings(
            rows: rows,
            defaults: defaults,
            read: read,
            codexStorageMode: codexStorageMode(among: defaults),
            exists: directoryExists,
            report: report
        )
    }

    public static func standingsWithoutAsking(
        rows: [AgentAccountRow],
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes()
    ) async -> [AgentAccountStanding] {
        await standings(rows: rows, defaults: defaults, report: { _ in .unanswered })
    }

    static func directoryExists(_ home: AgentAccountHome) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: home.directory.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    static func read(_ home: AgentAccountHome) -> (identity: Data?, credential: Data?) {
        (
            identity: try? Data(contentsOf: home.identityPath),
            credential: try? Data(contentsOf: home.credentialPath)
        )
    }

    static func codexStorageMode(among defaults: [AgentAccountHome]) -> CodexAuthStorageMode {
        let config = defaults.first { $0.provider == .codex }?
            .directory.appending(path: "config.toml")
        return CodexAuthStorageMode.read(configTOML: config.flatMap { try? Data(contentsOf: $0) })
    }
}
