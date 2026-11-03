import Testing
@testable import Core

@Suite("Second window")
struct SecondWindowTests {
    @Test func rankTheFlagsTheWayTheCaptureOpensThem() {
        #expect(SecondWindow.wanted(
            repoSettings: true, about: true, welcome: true, stage: .spend, settings: true
        ) == .repoSettings)
        #expect(SecondWindow.wanted(
            repoSettings: false, about: true, welcome: true, stage: .spend, settings: true
        ) == .about)
        #expect(SecondWindow.wanted(
            repoSettings: false, about: false, welcome: true, stage: .spend, settings: true
        ) == .welcome)
        #expect(SecondWindow.wanted(
            repoSettings: false, about: false, welcome: false, stage: .spend, settings: true
        ) == .spend)
        #expect(SecondWindow.wanted(
            repoSettings: false, about: false, welcome: false, stage: .window, settings: true
        ) == .settings)
    }

    @Test func knowsTheSceneOfEveryWindowThatHasOne() {
        #expect(SecondWindow.spend.identifier == "spend")
        #expect(SecondWindow.settings.identifier == "settings")
        #expect(SecondWindow.repoSettings.identifier == "repo-settings")
        #expect(SecondWindow.about.identifier == nil)
        #expect(SecondWindow.welcome.identifier == nil)
    }

    @Test func tellsTheSettingsWindowFromTheProjectOne() {
        for window in SecondWindow.allCases {
            guard let scene = window.identifier else { continue }
            let others = SecondWindow.allCases
                .filter { $0 != window }
                .compactMap(\.identifier)
            for other in others {
                #expect(!WindowScene.names(other, scene), "\(other) must not answer for \(scene)")
            }
        }
    }
}
