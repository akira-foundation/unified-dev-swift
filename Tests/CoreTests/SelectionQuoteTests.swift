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

    @Test func appendsToEmptyDraftWithTrailingBlankLine() {
        #expect(SelectionQuote.appending("> a", to: "") == "> a\n\n")
    }

    @Test func appendsAfterExistingTextWithoutLosingIt() {
        #expect(SelectionQuote.appending("> a", to: "Hi\n") == "Hi\n\n> a\n\n")
    }

    @Test(arguments: [
        (MessageKind.user, true), (.assistantText, true), (.thinking, false),
        (.toolUse, false), (.toolResult, false), (.error, false), (.notice, false)
    ])
    func acceptsOnlyMessagesAndAnswers(kind: MessageKind, expected: Bool) {
        #expect(SelectionActions.accepts(kind) == expected)
    }

    @Test func branchingNeedsAnActiveWorkspaceChat() {
        #expect(SelectionActions.canBranch(isAsk: false, isSideConversation: false, workspaceIsActive: true))
        #expect(!SelectionActions.canBranch(isAsk: true, isSideConversation: false, workspaceIsActive: true))
        #expect(!SelectionActions.canBranch(isAsk: false, isSideConversation: true, workspaceIsActive: true))
        #expect(!SelectionActions.canBranch(isAsk: false, isSideConversation: false, workspaceIsActive: false))
    }
}
