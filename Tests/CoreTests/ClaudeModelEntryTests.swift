import Foundation
import Testing
@testable import Core

@Suite("Claude model entry", .tags(.agentProtocol))
struct ClaudeModelEntryTests {
    @Test("the model released today is accepted and spelled the way the CLI takes it", arguments: [
        ("opus-5-5", "claude-opus-5-5"),
        ("Opus 5.5", "claude-opus-5-5"),
        ("  sonnet-5-2  ", "claude-sonnet-5-2"),
        ("opus-5-5-1m", "claude-opus-5-5[1m]"),
        ("claude-opus-5-5-20261101", "claude-opus-5-5-20261101"),
    ])
    func acceptsANewModel(typed: String, id: String) {
        #expect(ClaudeModelEntry.accept(typed).id == id)
    }

    @Test("a family with no version is the alias the CLI already understands", arguments: [
        "opus", "sonnet", "haiku", "fable",
    ])
    func acceptsABareFamily(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == typed)
    }

    @Test("a family Unified Dev has never heard of is accepted inside a full id")
    func acceptsAnUnknownFamilyWithAVersion() {
        #expect(ClaudeModelEntry.accept("claude-titan-1").id == "claude-titan-1")
    }

    @Test("nothing typed is refused before it reaches the fallback", arguments: ["", "   ", "\t\n"])
    func refusesBlankInput(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
    }

    @Test("another backend's model is refused rather than handed to Claude", arguments: [
        "gpt-5", "grok-4", "gemini-3-pro",
    ])
    func refusesAnotherBackend(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
    }

    @Test("a prefix with no model behind it is refused", arguments: [
        "claude-", "claude-foo", "claude", "5-5", "opus-",
    ])
    func refusesAnEmptyPrefix(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
    }

    @Test("a paste longer than any real id is refused")
    func refusesARunawayPaste() {
        #expect(ClaudeModelEntry.accept("opus-" + String(repeating: "5-", count: 40)).id == nil)
    }

    @Test("a shell fragment is refused rather than carried into argv", arguments: [
        "opus-5-5; rm -rf /", "opus$(whoami)", "opus/../../etc/passwd", "opus 5 5 --settings x",
    ])
    func refusesAShellFragment(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
    }

    @Test("a refusal says what to write instead")
    func refusalCarriesTheHint() {
        let refusal = ClaudeModelEntry.accept("gpt-5").refusal

        #expect(refusal?.contains("opus-5-5") == true)
    }

    @Test("what was accepted stays accepted when it is typed back in")
    func acceptingIsIdempotent() {
        guard let once = ClaudeModelEntry.accept("opus-5-5").id else {
            Issue.record("opus-5-5 was refused")
            return
        }

        #expect(ClaudeModelEntry.accept(once).id == once)
    }
}
