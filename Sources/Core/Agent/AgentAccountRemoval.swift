import Foundation

public enum AgentAccountError: Error, Equatable, LocalizedError {
    case isDefault(AgentAccountID)
    case inUse(workspaces: [String])
    case folderLeftAlone(String)
    case folderAlreadyThere(String)
    case folderInUse(String)
    case folderUseUnknown(String)
    case forgottenWithFolderKept(String)

    public var errorDescription: String? {
        switch self {
        case .isDefault:
            "The default account belongs to the agent itself, so Unified Dev does not remove it."
        case .inUse(let workspaces):
            "An agent is running under this account in \(workspaces.joined(separator: ", ")). Stop it first, or reopen Unified Dev if it has already stopped."
        case .folderLeftAlone(let path):
            "The folder is not where Unified Dev expected it, so it was left alone: \(path)"
        case .folderAlreadyThere(let path):
            "A folder for this account already exists, so Unified Dev did not reuse it: \(path)"
        case .folderInUse(let path):
            "A process is still using this account's folder, so Unified Dev left it alone. Stop it and remove the account again: \(path)"
        case .folderUseUnknown(let path):
            "Unified Dev could not tell whether anything is still using this account's folder, so it left it alone: \(path)"
        case .forgottenWithFolderKept(let path):
            "The account was forgotten, but its folder may still be in use, so Unified Dev left it alone. It is listed as an unfinished sign-in: \(path)"
        }
    }
}

public enum AgentAccountRemoval {
    public struct Warning: Sendable, Equatable {
        public let title: String
        public let message: String
        public let actionTitle: String
    }

    public static func warning(
        forAccountNamed title: String, folderExists: Bool, chosenBy projects: [String] = []
    ) -> Warning {
        let consequence = folderExists
            ? "This deletes the account's folder on this Mac, including its saved sign-in and the conversation transcripts kept there."
            : "The account's folder is already gone, so this only forgets the account."
        return Warning(
            title: "Remove \(title)?",
            message: consequence
                + fallsBack(projects)
                + " Unified Dev cannot remove the entry this account left in your keychain,"
                + " so remove it in Keychain Access if you want it gone.",
            actionTitle: "Remove account"
        )
    }

    private static func fallsBack(_ projects: [String]) -> String {
        let names = projects.sorted()
        guard !names.isEmpty else { return " Anything that used this account goes back to the default account." }
        let verb = names.count > 1 ? "go" : "goes"
        return " \(ProfileAccountNotice.list(names)) \(verb) back to the default account of the profile."
    }

    public static func warningForUnfinishedSignIn(named title: String) -> Warning {
        Warning(
            title: "Remove \(title)?",
            message: "This deletes the folder of a sign-in that did not finish, including anything saved in it."
                + " Unified Dev cannot remove the entry it may have left in your keychain,"
                + " so remove it in Keychain Access if you want it gone.",
            actionTitle: "Remove folder"
        )
    }

    public static func directory(of home: AgentAccountHome, support: URL) -> URL? {
        guard home.directory.lastPathComponent == home.id.rawValue else { return nil }
        let expected = AgentAccountHomes.directory(for: home.id, provider: home.provider, support: support)
        let settled = TranscriptHome.settled(home.directory)
        guard settled == TranscriptHome.settled(expected),
              TranscriptHome.isInside(settled: settled, of: TranscriptHome.settled(AgentAccountHomes.root(support: support)))
        else { return nil }
        return home.directory
    }

    public static func remove(
        _ home: AgentAccountHome,
        support: URL,
        store: Store,
        processes: @Sendable () -> [ProcessVector]? = ProcessVectors.ofOtherProcesses
    ) async throws {
        guard !home.isDefault, !AgentAccountHome.isDefaultID(home.id) else {
            throw AgentAccountError.isDefault(home.id)
        }
        let running = try await AgentAccountUsage.runningWorkspaces(under: home, store: store)
        guard running.isEmpty else { throw AgentAccountError.inUse(workspaces: running) }
        if let directory = directory(of: home, support: support) {
            try requireNothingHolds(directory, processes: processes)
        }
        try await store.forgetAgentAccount(home.id)
        do {
            try deleteFolder(of: home, support: support, processes: processes)
        } catch AgentAccountError.folderInUse(let path), AgentAccountError.folderUseUnknown(let path) {
            throw AgentAccountError.forgottenWithFolderKept(path)
        }
    }

    public static func remove(
        _ row: AgentAccountPanel.Row,
        support: URL,
        store: Store,
        processes: @Sendable () -> [ProcessVector]? = ProcessVectors.ofOtherProcesses
    ) async throws {
        guard row.isUnfinished else {
            try await remove(row.home, support: support, store: store, processes: processes)
            return
        }
        try removeUnfinished(row.home, support: support, processes: processes)
    }

    public static func removeUnfinished(
        _ home: AgentAccountHome,
        support: URL,
        processes: () -> [ProcessVector]? = ProcessVectors.ofOtherProcesses
    ) throws {
        guard !home.isDefault else { throw AgentAccountError.isDefault(home.id) }
        try deleteFolder(of: home, support: support, processes: processes)
    }

    private static func deleteFolder(
        of home: AgentAccountHome, support: URL, processes: () -> [ProcessVector]?
    ) throws {
        guard let directory = directory(of: home, support: support) else {
            throw AgentAccountError.folderLeftAlone(home.directory.path)
        }
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try requireNothingHolds(directory, processes: processes)
        try FileManager.default.removeItem(at: directory)
    }

    private static func requireNothingHolds(_ directory: URL, processes: () -> [ProcessVector]?) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try AgentAccountFolderUse.of(directory, among: processes()).requireFree(path: directory.path)
    }
}
