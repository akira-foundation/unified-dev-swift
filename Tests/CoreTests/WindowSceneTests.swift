import Testing
@testable import Core

@Suite("Window scene")
struct WindowSceneTests {
    @Test func namesTheSceneItWasAskedAbout() {
        #expect(WindowScene.names("settings", "settings"))
        #expect(WindowScene.names("main-AppWindow-1", "main"))
        #expect(WindowScene.names("spend-AppWindow-2", "spend"))
    }

    @Test func refusesASceneThatMerelyContainsTheName() {
        #expect(!WindowScene.names("repo-settings", "settings"))
        #expect(!WindowScene.names("repo-settings-AppWindow-1", "settings"))
        #expect(!WindowScene.names("domain", "main"))
        #expect(!WindowScene.names("remains", "main"))
    }

    @Test func refusesAWindowWithNoIdentifierAtAll() {
        #expect(!WindowScene.names(nil, "settings"))
        #expect(!WindowScene.names("", "settings"))
    }
}
