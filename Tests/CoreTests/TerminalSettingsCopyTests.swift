import Testing
import Foundation
@testable import Core

@Suite("Terminal settings copy")
struct TerminalSettingsCopyTests {
    @Test("an override says it has stopped following Ghostty")
    func overrideWins() {
        let line = TerminalSettingsCopy.textSizeSource(override: 15, ghostty: 13)

        #expect(line == "Set here, so it no longer follows Ghostty.")
    }

    @Test("with no override the Ghostty size is named")
    func followsGhostty() {
        let line = TerminalSettingsCopy.textSizeSource(override: nil, ghostty: 13)

        #expect(line.contains("13 pt"))
        #expect(line.contains("Ghostty"))
    }

    @Test("a fractional Ghostty size is said in whole points")
    func roundsGhosttySize() {
        let line = TerminalSettingsCopy.textSizeSource(override: nil, ghostty: 13.5)

        #expect(line.contains("13 pt"))
    }

    @Test("with neither, the system size is named rather than left unexplained")
    func fallsBackToSystem() {
        let line = TerminalSettingsCopy.textSizeSource(override: nil, ghostty: nil)

        #expect(line.contains("system monospaced"))
        #expect(line.contains("No Ghostty configuration"))
    }

    @Test("without tmux the sentence says what to install")
    func namesTheMissingDependency() {
        let line = TerminalSettingsCopy.persistence(isTmuxInstalled: false)

        #expect(line.contains("brew install tmux"))
    }

    @Test("with tmux the archive guarantee is still stated")
    func keepsTheArchiveGuarantee() {
        let line = TerminalSettingsCopy.persistence(isTmuxInstalled: true)

        #expect(line.contains("Archiving a workspace always stops its terminals"))
    }
}
