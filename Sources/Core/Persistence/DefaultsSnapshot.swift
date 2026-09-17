import Foundation

public enum DefaultsSnapshot {
    public static func own(_ defaults: UserDefaults, name: String?) -> [String: Any] {
        guard let name else { return defaults.dictionaryRepresentation() }
        return defaults.persistentDomain(forName: name) ?? [:]
    }
}
