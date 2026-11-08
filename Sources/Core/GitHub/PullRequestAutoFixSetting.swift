import Foundation

public enum PullRequestAutoFixSetting {
    public static let settingTitle = "Ask to fix conflicts and failed checks automatically"

    public static let settingHeader = "Pull requests"

    public static let caveat = "The agent gets the same request as Ask to fix without waiting for you, at most three "
        + "times in a row on a pull request, and you are told when it stops. Only pull requests you opened from this "
        + "repository are covered. A failed check's log is text the agent reads, and nobody reads it first."

    public static let saveFailure = "This could not be saved, so it is as it was."

    private static let storedOn = "on"

    static func key(repoID: RepoID) -> String {
        "repo.\(repoID).pullRequestAutoFix"
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
