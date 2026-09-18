import Foundation
import Testing

@Suite("Test defaults stay in the scratch directory")
struct TestDefaultsTests {
    @Test("a written key lands in a file inside the scratch directory")
    func landsInScratch() {
        let (name, defaults) = TestDefaults.make("probe")
        defaults.set("value", forKey: "key")
        defaults.synchronize()

        #expect(name.hasPrefix(TestProcessScratch.root))
        #expect(FileManager.default.fileExists(atPath: name + ".plist"))
        #expect(UserDefaults(suiteName: name)?.string(forKey: "key") == "value")
    }

    @Test("nothing named after the suite reaches the user's Preferences folder")
    func nothingInPreferences() throws {
        let (name, defaults) = TestDefaults.make("probe")
        defaults.set(true, forKey: "key")
        defaults.synchronize()

        let marker = ((name as NSString).deletingLastPathComponent as NSString).lastPathComponent
        let preferences = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences").path
        let listed = try FileManager.default.contentsOfDirectory(atPath: preferences)
        #expect(!listed.contains { $0.contains(marker) })
    }

    @Test("two tests with the same label get separate domains")
    func labelsDoNotCollide() {
        let first = TestDefaults.make("probe")
        let second = TestDefaults.make("probe")
        first.defaults.set(1, forKey: "key")

        #expect(first.name != second.name)
        #expect(second.defaults.object(forKey: "key") == nil)
    }
}
