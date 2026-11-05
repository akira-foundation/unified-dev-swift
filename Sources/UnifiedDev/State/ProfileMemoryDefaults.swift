import Foundation
import Core

enum ProfileMemoryDefaults {
    private static let key = "profile.lastWorkspaces"
    private static let legacyKey = "sidebar.lastWorkspaceID"

    static func load() -> ProfileMemory {
        let defaults = UserDefaults.standard
        let stored = defaults.data(forKey: key)
        let memory = ProfileMemory.restored(
            stored: stored, legacyLastWorkspace: defaults.string(forKey: legacyKey)
        )
        if stored == nil { save(memory) }
        return memory
    }

    static func save(_ memory: ProfileMemory) {
        guard let encoded = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }
}
