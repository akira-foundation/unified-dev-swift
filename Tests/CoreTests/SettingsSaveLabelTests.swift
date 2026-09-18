import Testing
@testable import Core

@Suite("What a settings section says about its file")
struct SettingsSaveLabelTests {
    private let destination = ".unifieddev/settings.toml"

    @Test("at rest the section names the file it writes to")
    func atRestItNamesTheFile() {
        #expect(
            SettingsSaveLabel.text(destination: destination, phase: .idle)
                == "Saved to .unifieddev/settings.toml"
        )
    }

    @Test("a typed change that has not been written says so")
    func pendingSaysSo() {
        #expect(SettingsSaveLabel.text(destination: destination, phase: .pending) == "Unsaved changes")
    }

    @Test("the write itself is named while it runs")
    func writingSaysSo() {
        #expect(SettingsSaveLabel.text(destination: destination, phase: .writing) == "Saving")
    }

    @Test("a finished write is acknowledged before the file name comes back")
    func wroteIsAcknowledged() {
        #expect(SettingsSaveLabel.text(destination: destination, phase: .wrote) == "Saved just now")
    }

    @Test("a failed write says what went wrong instead of the file name")
    func failureCarriesItsReason() {
        #expect(
            SettingsSaveLabel.text(destination: destination, phase: .failed("permission denied"))
                == "Not saved: permission denied"
        )
    }

    @Test("a section with no file of its own still reads sensibly")
    func noDestination() {
        #expect(SettingsSaveLabel.text(destination: "", phase: .idle) == "")
        #expect(SettingsSaveLabel.text(destination: "", phase: .pending) == "Unsaved changes")
    }

    @Test("only a failure is a failure")
    func onlyFailureIsAFailure() {
        #expect(!SettingsSaveLabel.isFailure(.idle))
        #expect(!SettingsSaveLabel.isFailure(.pending))
        #expect(!SettingsSaveLabel.isFailure(.writing))
        #expect(!SettingsSaveLabel.isFailure(.wrote))
        #expect(SettingsSaveLabel.isFailure(.failed("x")))
    }
}
