import Foundation

public enum ProfileBridgeSwitch {
    public static let settingTitle = "Connected to other profiles"

    public static let caveat = "With this on in two profiles, a project's orchestrator in one can reach the "
        + "other, and you approve each call. Your own chat and client reach any profile with this on, "
        + "without asking. They can list its work, read its chats and changes, and send a message that "
        + "wakes an agent, which arrives marked as coming from outside. Nothing can be started there. "
        + "Text planted in something your chat or an orchestrator reads could still carry one "
        + "organisation's work into another."

    public static let saveFailure = "This could not be saved, so it is as it was."

    private static let storedOn = "on"

    static func key(profile: ProfileID) -> String {
        "profile.\(profile).reachableFromOtherProfiles"
    }

    public static func parse(_ stored: String?) -> Bool {
        stored == storedOn
    }

    public static func isOn(profile: ProfileID, in store: Store) async -> Bool {
        parse(try? await store.setting(key(profile: profile)))
    }

    public static func save(_ isOn: Bool, profile: ProfileID, to store: Store) async throws {
        try await store.setSetting(key(profile: profile), isOn ? storedOn : nil)
    }
}
