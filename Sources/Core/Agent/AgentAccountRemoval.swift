import Foundation

public enum AgentAccountError: Error, Equatable, LocalizedError {
    case isDefault(AgentAccountID)

    public var errorDescription: String? {
        switch self {
        case .isDefault:
            "The default account belongs to the agent itself, so Unified Dev does not remove it."
        }
    }
}

public enum AgentAccountRemoval {
    public struct Warning: Sendable, Equatable {
        public let title: String
        public let message: String
    }

    public static func warning(forAccountNamed title: String, folderExists: Bool) -> Warning {
        let consequence = folderExists
            ? "This deletes the account's folder on this Mac, including its saved sign-in and the conversation transcripts kept there."
            : "The account's folder is already gone, so this only forgets the account."
        return Warning(
            title: "Remove \(title)?",
            message: consequence
                + " Anything that used this account goes back to the default account."
                + " Unified Dev cannot remove the entry this account left in your keychain,"
                + " so remove it in Keychain Access if you want it gone."
        )
    }

    public static func directory(of home: AgentAccountHome, support: URL) -> URL? {
        let expected = AgentAccountHomes.directory(for: home.id, provider: home.provider, support: support)
        guard TranscriptHome.settled(home.directory) == TranscriptHome.settled(expected) else { return nil }
        return home.directory
    }

    public static func remove(_ home: AgentAccountHome, support: URL, store: Store) async throws {
        guard !home.isDefault, !AgentAccountHome.isDefaultID(home.id) else {
            throw AgentAccountError.isDefault(home.id)
        }
        if let directory = directory(of: home, support: support),
           FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try await store.forgetAgentAccount(home.id)
    }
}
