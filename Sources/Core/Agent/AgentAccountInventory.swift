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

    public static func concluding(
        _ plan: AgentAccountCreation,
        exit: TerminalExit?,
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes(),
        report: @Sendable (AgentAccountHome) async -> AgentAccountLiveness.CliReport = {
            await AgentAccountLiveness().report(for: $0)
        }
    ) async -> AgentAccountStanding? {
        guard exit == .exited(0) else { return nil }
        let files = read(plan.home)
        return AgentAccountCreation.settled(
            plan,
            identity: files.identity,
            credential: files.credential,
            report: await report(plan.home),
            codexStorageMode: codexStorageMode(among: defaults)
        )
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

    public static func codexStorageMode(among defaults: [AgentAccountHome]) -> CodexAuthStorageMode {
        let config = defaults.first { $0.provider == .codex }?
            .directory.appending(path: "config.toml")
        return CodexAuthStorageMode.read(configTOML: config.flatMap { try? Data(contentsOf: $0) })
    }
}
