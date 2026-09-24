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

    @Test("an alias the CLI takes with no hyphen in it is accepted", arguments: [
        "opusplan", "opusplan[1m]",
    ])
    func acceptsAnAliasWithNoHyphen(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == typed)
    }

    @Test("a window suffix is accepted only in the shape the CLI writes it", arguments: [
        "opus][", "claude-a1[[[]]]", "opus-5[2m]", "opus[1m", "opus-5]1m[",
    ])
    func refusesAMalformedWindow(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
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

    @Test("an id that would read as a flag is refused", arguments: [
        "-opus-5", "--model", "-claude-opus-5-5",
    ])
    func refusesALeadingDash(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
    }

    @Test("a family spelled with a letter that only looks Latin is refused")
    func refusesAHomoglyph() {
        #expect(ClaudeModelEntry.accept("claude-\u{043E}pus-5").id == nil)
    }

    @Test("length alone is enough to refuse an id that is otherwise well formed")
    func refusesOnLengthAlone() {
        let typed = "claude-opus-" + String(repeating: "5-", count: 40) + "5"

        #expect(typed.allSatisfy(ClaudeModelEntry.isAllowed))
        #expect(!typed.hasSuffix("-"))
        #expect(ClaudeModelEntry.accept(typed).id == nil)
    }

    @Test("a refusal says what to write instead")
    func refusalCarriesTheHint() {
        let refusal = ClaudeModelEntry.accept("gpt-5").refusal

        #expect(refusal?.contains("opus-5-5") == true)
    }

    @Test("an empty field is told to write something rather than told it is unreadable")
    func blankAsksForAModel() {
        #expect(ClaudeModelEntry.accept("   ").refusal == "Write a model first. "
            + ClaudeModelEntry.hint)
    }

    @Test("a prefix with digits and no family is refused", arguments: ["claude-2024", "claude-5"])
    func refusesDigitsWithNoFamily(typed: String) {
        #expect(ClaudeModelEntry.accept(typed).id == nil)
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
