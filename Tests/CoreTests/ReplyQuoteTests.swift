import Testing
@testable import Core

@Suite("Reply quote")
struct ReplyQuoteTests {
    private func quote(_ selection: String) throws -> ReplyQuote {
        try #require(ReplyQuote(selection: selection))
    }

    @Test func blankSelectionMakesNoQuote() {
        #expect(ReplyQuote(selection: " \n\u{FFFC}\n ") == nil)
    }

    @Test func summaryReadsAsOneLine() throws {
        #expect(try quote("  first\n\n   second\tthird \u{FFFC}\n").summary == "first second third")
    }

    @Test func blankSelectionHasNoSummary() {
        #expect(ReplyQuote.summary(of: " \n\u{FFFC}\t") == nil)
    }

    @Test func twoQuotesOfTheSameTextStayApart() throws {
        #expect(try quote("same").id != quote("same").id)
    }

    @Test func mergingKeepsStoredQuotesBeforeTheOnesAddedSince() throws {
        let stored = try quote("stored")
        let added = try quote("added while reading")
        let merged = ReplyQuote.merging(stored: [stored, added], into: [added], removed: [])
        #expect(merged == [stored, added])
    }

    @Test func mergingDropsAQuoteRemovedWhileReading() throws {
        let removed = try quote("removed while reading")
        let kept = try quote("kept")
        let merged = ReplyQuote.merging(stored: [removed, kept], into: [], removed: [removed.id])
        #expect(merged == [kept])
    }

    @Test func messageIsTheTextWhenNothingIsQuoted() {
        #expect(ReplyQuote.message("  hello\n", quoting: []) == "  hello\n")
    }

    @Test func messagePutsQuotesBeforeTheText() throws {
        let message = ReplyQuote.message("why?\n", quoting: [try quote("one\ntwo"), try quote("three")])
        #expect(message == "> one\n> two\n\n> three\n\nwhy?")
    }

    @Test func messageIsOnlyTheQuotesWhenNothingWasTyped() throws {
        #expect(ReplyQuote.message(" \n", quoting: [try quote("one")]) == "> one")
    }

    @Test func messageKeepsASlashCommandFirst() throws {
        #expect(ReplyQuote.message("/commit now", quoting: [try quote("one")]) == "/commit now\n\n> one")
    }

    @Test func draftTakesTheTypedReply() {
        #expect(ReplyQuote.draft("", adding: " why?\n") == "why?")
    }

    @Test func draftKeepsWhatWasAlreadyThere() {
        #expect(ReplyQuote.draft("first\n\n", adding: "why?") == "first\n\nwhy?")
    }

    @Test func draftIsUntouchedWhenNothingWasTyped() {
        #expect(ReplyQuote.draft("first\n", adding: "  ") == "first\n")
    }
}
