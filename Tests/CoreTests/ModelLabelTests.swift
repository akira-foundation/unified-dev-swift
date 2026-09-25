import Foundation
import Testing
@testable import Core

@Suite("Model labels")
struct ModelLabelTests {
    @Test("a version keeps its full stop rather than becoming two words")
    func versionsAreRejoined() {
        #expect(ModelLabel.readable("claude-opus-4-6") == "Opus 4.6")
        #expect(ModelLabel.readable("claude-opus-4-5") == "Opus 4.5")
        #expect(ModelLabel.readable("claude-sonnet-4-5-20251001") == "Sonnet 4.5.20251001")
    }

    @Test("a single version part is left as it was")
    func singleVersionPart() {
        #expect(ModelLabel.readable("claude-opus-5") == "Opus 5")
        #expect(ModelLabel.readable("claude-fable-5") == "Fable 5")
        #expect(ModelLabel.readable("claude-fable-5-1") == "Fable 5.1")
    }

    @Test("a context window stays a separate word")
    func contextWindowsAreNotVersions() {
        #expect(ModelLabel.readable("opus-5-1m") == "Opus 5 1m")
        #expect(ModelLabel.readable("claude-opus-5[1m]") == "Opus 5 (1m)")
    }

    @Test("a point release keeps its full stop in front of a context window")
    func windowDoesNotSwallowThePointRelease() {
        #expect(ModelLabel.readable("claude-opus-5-5[1m]") == "Opus 5.5 (1m)")
        #expect(ModelLabel.readable("claude-opus-5-5") == "Opus 5.5")
    }

    @Test("the vendor prefix goes, because inside Unified Dev every model is a Claude model")
    func vendorIsDropped() {
        #expect(ModelLabel.readable("claude-haiku-4-5") == "Haiku 4.5")
    }

    @Test("unless the vendor name is all there is, which would leave nothing to read")
    func vendorAloneSurvives() {
        #expect(ModelLabel.readable("claude") == "Claude")
    }

    @Test("a permission mode reads as a mode")
    func permissionModes() {
        #expect(ModelLabel.readable("acceptEdits") == "AcceptEdits")
        #expect(ModelLabel.readable("bypass_permissions") == "Bypass Permissions")
    }

    @Test("an id with nothing in it comes back as it went in rather than as an empty chip")
    func emptyIsUnchanged() {
        #expect(ModelLabel.readable("") == "")
        #expect(ModelLabel.readable("---") == "---")
    }

    @Test("a part that does not start with a letter is not capitalised into nonsense")
    func nonLettersAreLeftAlone() {
        #expect(ModelLabel.readable("gpt-5-codex") == "GPT 5 Codex")
        #expect(ModelLabel.readable("gpt-5-6-luna") == "GPT 5.6 Luna")
        #expect(ModelLabel.readable("o3-mini") == "O3 Mini")
    }
}
