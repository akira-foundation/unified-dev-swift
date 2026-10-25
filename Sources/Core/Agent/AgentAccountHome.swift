import Foundation

public struct AgentAccountHome: Sendable, Hashable {
    public let provider: AgentKind
    public let id: AgentAccountID
    public let directory: URL
    public let isDefault: Bool

    public init(provider: AgentKind, id: AgentAccountID, directory: URL, isDefault: Bool) {
        self.provider = provider
        self.id = id
        self.directory = directory
        self.isDefault = isDefault
    }

    public static func defaultID(for provider: AgentKind) -> AgentAccountID {
        AgentAccountID("default." + provider.rawValue)
    }

    public static func defaultHome(for provider: AgentKind, home: URL) -> AgentAccountHome? {
        guard let name = defaultDirectoryName(for: provider) else { return nil }
        return AgentAccountHome(
            provider: provider,
            id: defaultID(for: provider),
            directory: home.appending(path: name, directoryHint: .isDirectory),
            isDefault: true
        )
    }

    public var identityPath: URL {
        switch provider {
        case .claudeCode:
            claudeIdentityDirectory.appending(path: ".claude.json")
        case .codex, .grok, .cursor, .openCode:
            directory.appending(path: "auth.json")
        }
    }

    private var claudeIdentityDirectory: URL {
        if isDefault { return directory.deletingLastPathComponent() }
        return directory
    }

    public var credentialPath: URL {
        switch provider {
        case .claudeCode: directory.appending(path: ".credentials.json")
        case .codex, .grok, .cursor, .openCode: directory.appending(path: "auth.json")
        }
    }

    private static func defaultDirectoryName(for provider: AgentKind) -> String? {
        switch provider {
        case .claudeCode: ".claude"
        case .codex: ".codex"
        case .grok: ".grok"
        case .cursor, .openCode: nil
        }
    }
}
