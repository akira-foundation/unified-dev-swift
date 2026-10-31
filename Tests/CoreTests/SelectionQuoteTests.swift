import Testing
@testable import Core

@Suite("Selection quote")
struct SelectionQuoteTests {
    @Test func quotesEveryLineIncludingBlankOnes() {
        #expect(SelectionQuote.quote("one\n\ntwo") == "> one\n>\n> two")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(SelectionQuote.quote("\n  hello  \n") == "> hello")
    }

    @Test func keepsCodeIndentation() {
        #expect(SelectionQuote.quote("func a() {\n    return 1\n}") == "> func a() {\n>     return 1\n> }")
    }

    @Test func splitsWindowsAndUnicodeLineBreaks() {
        #expect(SelectionQuote.quote("one\r\ntwo\u{2028}three") == "> one\n> two\n> three")
    }

    @Test func dropsAttachmentGlyphs() {
        #expect(SelectionQuote.quote("\u{FFFC} Foo.swift") == "> Foo.swift")
    }

    @Test(arguments: ["", "   ", "\n\n\t", "\u{FFFC}"])
    func blankSelectionHasNoQuote(text: String) {
        #expect(SelectionQuote.quote(text) == nil)
    }

    @Test func trimsTrailingSpacesOnInteriorLines() {
        #expect(SelectionQuote.quote("a  \n   \nb") == "> a\n>\n> b")
    }

    @Test func removesOnlyTheCommonIndent() {
        #expect(SelectionQuote.quote("    a\n  b") == ">   a\n> b")
    }

    @Test func appendsAfterSeveralTrailingNewlines() {
        #expect(SelectionQuote.appending("> a", to: "Hi\n\n\n") == "Hi\n\n> a\n\n")
    }

    @Test func appendsASecondQuoteAfterTheFirst() {
        #expect(SelectionQuote.appending("> b", to: "> a\n\n") == "> a\n\n> b\n\n")
    }

    @Test func appendsToEmptyDraftWithTrailingBlankLine() {
        #expect(SelectionQuote.appending("> a", to: "") == "> a\n\n")
    }

    @Test func appendsAfterExistingTextWithoutLosingIt() {
        #expect(SelectionQuote.appending("> a", to: "Hi\n") == "Hi\n\n> a\n\n")
    }
}
