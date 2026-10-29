import Foundation

public struct AgentAccountStanding: Sendable, Hashable {
    public let home: AgentAccountHome
    public let identity: AgentAccountIdentity
    public let cliReport: AgentAccountLiveness.CliReport
    public let isolationDoubt: String?

    public var isolationIsGuaranteed: Bool { isolationDoubt == nil }

    public init(
        home: AgentAccountHome,
        identity: AgentAccountIdentity,
        cliReport: AgentAccountLiveness.CliReport,
        isolationDoubt: String?
    ) {
        self.home = home
        self.identity = identity
        self.cliReport = cliReport
        self.isolationDoubt = isolationDoubt
    }
}

public enum AgentAccountRoster {
    public static func standings(
        rows: [AgentAccountRow],
        defaults: [AgentAccountHome],
        read: (AgentAccountHome) -> (identity: Data?, credential: Data?),
        codexStorageMode: CodexAuthStorageMode,
        report: @escaping @Sendable (AgentAccountHome) async -> AgentAccountLiveness.CliReport
    ) async -> [AgentAccountStanding] {
        let homes = defaults + rows.map(home)
        let identities = homes.map { home in
            let files = read(home)
            return AgentAccountIdentity.read(home, identity: files.identity, credential: files.credential)
        }
        let reports = await reports(for: homes, report: report)
        return homes.indices.map { index in
            AgentAccountStanding(
                home: homes[index],
                identity: identities[index],
                cliReport: reports[index],
                isolationDoubt: isolationDoubt(for: homes[index].provider, codexStorageMode: codexStorageMode)
            )
        }
    }

    static func isolationDoubt(for provider: AgentKind, codexStorageMode: CodexAuthStorageMode) -> String? {
        switch provider {
        case .claudeCode:
            nil
        case .codex:
            switch codexStorageMode {
            case .file: nil
            case .keyring:
                "Codex keeps its login in the system keychain here, which a separate directory does not keep apart."
            }
        case .grok:
            "Grok has not been confirmed to keep a separate login per directory, because GROK_HOME was never verified."
        case .cursor, .openCode:
            "This agent has no setting that gives an account a directory of its own."
        }
    }

    private static func home(of row: AgentAccountRow) -> AgentAccountHome {
        AgentAccountHome(
            provider: row.provider,
            id: row.id,
            directory: URL(filePath: row.directory, directoryHint: .isDirectory),
            isDefault: row.isDefault
        )
    }

    private static func reports(
        for homes: [AgentAccountHome],
        report: @escaping @Sendable (AgentAccountHome) async -> AgentAccountLiveness.CliReport
    ) async -> [AgentAccountLiveness.CliReport] {
        await withTaskGroup(of: (Int, AgentAccountLiveness.CliReport).self) { group in
            for (index, home) in homes.enumerated() {
                group.addTask { (index, await report(home)) }
            }
            var answers = [AgentAccountLiveness.CliReport](repeating: .unanswered, count: homes.count)
            for await (index, answer) in group { answers[index] = answer }
            return answers
        }
    }
}
