import Foundation

public enum OrchestratorUnaskedCommands {
    public static let settingTitle = "Run commands without asking"

    public static let settingHeader = "Orchestrator"

    public static let caveat = "Text planted in a file or an issue the orchestrator reads can then run commands, "
        + "and you would not see them first. Edits, commits, pushes, merges and rebases it can recognise stay refused, "
        + "but a script or a build it runs can still do them. "
        + "A command it cannot read still asks, and so does a chat in a terminal."

    public static let saveFailure = "This could not be saved, so it is as it was."

    private static let storedOn = "on"

    static func key(repoID: RepoID) -> String {
        "repo.\(repoID).orchestratorRunsCommandsUnasked"
    }

    public static func parse(_ stored: String?) -> Bool {
        stored == storedOn
    }

    public static func isOn(repoID: RepoID, in store: Store) async -> Bool {
        parse(try? await store.setting(key(repoID: repoID)))
    }

    public static func save(_ isOn: Bool, repoID: RepoID, to store: Store) async throws {
        try await store.setSetting(key(repoID: repoID), isOn ? storedOn : nil)
    }
}
