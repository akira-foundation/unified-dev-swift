import Testing
@testable import Core

@Suite("Thinking text") struct ThinkingTextTests {
    @Test func theTwoNewlinesABlockEndsWithAreNotDrawn() {
        let block = "The row is taller than its text.\nSo the padding is not the cause.\n\n"
        #expect(ThinkingText.displayed(block)
            == "The row is taller than its text.\nSo the padding is not the cause.")
    }

    @Test func blankLinesInsideTheReasoningAreKept() {
        let block = "First paragraph.\n\nSecond paragraph."
        #expect(ThinkingText.displayed(block) == block)
    }

    @Test func leadingWhitespaceGoesTooSoTheTopMatchesTheBottom() {
        #expect(ThinkingText.displayed("\n\n  Planning\n") == "Planning")
    }

    @Test func carriageReturnsAndTabsAreWhitespace() {
        #expect(ThinkingText.displayed("Done.\r\n\t \r\n") == "Done.")
    }

    @Test func aBlockOfNothingButWhitespaceDrawsNothing() {
        #expect(ThinkingText.displayed("\n \n\t").isEmpty)
        #expect(ThinkingText.displayed("").isEmpty)
    }

    @Test func textWithNothingToTrimComesBackUnchanged() {
        let block = "One line, nothing around it."
        #expect(ThinkingText.displayed(block) == block)
    }

    @Test func accentedAndWideCharactersAtTheEdgesAreNotCut() {
        #expect(ThinkingText.displayed("\ncafé 思考\n\n") == "café 思考")
    }

    @Test func aShortStreamIsTrimmedWithoutAnEllipsis() {
        #expect(ThinkingText.tail("Reading the notes.\n\n", limit: 600) == "Reading the notes.")
    }

    @Test func aLongStreamKeepsItsEndBehindAnEllipsisAndLosesTheBlankLines() {
        let stream = String(repeating: "a", count: 20) + " the end.\n\n"
        #expect(ThinkingText.tail(stream, limit: 10) == "\u{2026}the end.")
    }

    @Test func aTailOfNothingButWhitespaceDrawsNothing() {
        let stream = String(repeating: "a", count: 20) + String(repeating: "\n", count: 12)
        #expect(ThinkingText.tail(stream, limit: 10).isEmpty)
    }
}
