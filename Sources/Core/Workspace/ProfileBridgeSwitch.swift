import Foundation

public enum ProfileBridgeSwitch {
    public static let settingTitle = "Reachable from other profiles"

    public static let caveat = "A project's orchestrator or your own chat in another profile can list this "
        + "profile's work, read its chats and changes, and send a message that wakes an agent here. "
        + "An orchestrator also needs this on in its own profile. Messages arrive marked as coming from "
        + "outside. Text planted in something an orchestrator reads could still carry one organisation's "
        + "work into another."

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
