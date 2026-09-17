import Foundation
import Testing
@testable import Core

@Suite("DefaultsSnapshot")
struct DefaultsSnapshotTests {
    private func domain() -> (name: String, defaults: UserDefaults) {
        let name = "unifieddev.test.snapshot.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    private func clean(_ name: String) {
        UserDefaults.standard.removePersistentDomain(forName: name)
    }

    @Test("a written key is in the snapshot and the global domain is not")
    func ownKeysOnly() {
        let (name, defaults) = domain()
        defer { clean(name) }
        defaults.set("v", forKey: "center.tab.s1")

        let snapshot = DefaultsSnapshot.own(defaults, name: name)

        #expect(snapshot["center.tab.s1"] as? String == "v")
        #expect(defaults.dictionaryRepresentation()["AppleLanguages"] != nil)
        #expect(snapshot["AppleLanguages"] == nil)
    }

    @Test("a registered key is not in the snapshot")
    func registeredKeysAreAbsent() {
        let (name, defaults) = domain()
        defer { clean(name) }
        defaults.register(defaults: ["center.tab.registered": "v"])

        #expect(defaults.string(forKey: "center.tab.registered") == "v")
        #expect(DefaultsSnapshot.own(defaults, name: name)["center.tab.registered"] == nil)
    }

    @Test("no domain name falls back to the merged representation")
    func namelessFallsBack() {
        let (name, defaults) = domain()
        defer { clean(name) }
        defaults.set("v", forKey: "center.tab.s1")

        #expect(DefaultsSnapshot.own(defaults, name: nil)["center.tab.s1"] as? String == "v")
    }
}
