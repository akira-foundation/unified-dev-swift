import Testing
@testable import Core

@Suite("Review comment discard")
struct ReviewCommentDiscardTests {
    @Test("an empty editor closes without a question", arguments: [
        "", "   ", "\n", " \t\n ",
    ])
    func closesQuietlyWhenEmpty(typed: String) {
        #expect(ReviewCommentDiscard.needed(closing: typed, replacing: nil) == nil)
    }

    @Test("a comment being written asks before it goes")
    func asksAboutWriting() {
        #expect(ReviewCommentDiscard.needed(closing: "this is wrong", replacing: nil) == .writing)
        #expect(ReviewCommentDiscard.needed(closing: "  a  ", replacing: nil) == .writing)
    }

    @Test("a rewrite asks, and says the comment survives")
    func asksAboutRewriting() {
        let question = ReviewCommentDiscard.needed(closing: "a better note", replacing: "old")
        #expect(question == .rewriting)
        #expect(question?.message.contains("keeps the text it already had") == true)
    }

    @Test("a rewrite that says what the comment already says closes without a question")
    func unchangedRewriteClosesQuietly() {
        #expect(ReviewCommentDiscard.needed(closing: "same", replacing: "same") == nil)
        #expect(ReviewCommentDiscard.needed(closing: " same \n", replacing: "same") == nil)
    }

    @Test("an emptied rewrite closes without a question")
    func emptiedRewriteClosesQuietly() {
        #expect(ReviewCommentDiscard.needed(closing: "", replacing: "old") == nil)
        #expect(ReviewCommentDiscard.needed(closing: "  \n ", replacing: "old") == nil)
    }

    @Test("whitespace the trim removes is not something to lose")
    func storedEdgesAreNotAChange() {
        #expect(ReviewCommentDiscard.needed(closing: "note", replacing: "note ") == nil)
        #expect(ReviewCommentEdit.outcome(typed: "note", replacing: "note ") == .save("note"))
    }

    @Test("the two questions say different things about the same loss")
    func wordsDiffer() {
        #expect(ReviewCommentDiscard.writing.title != ReviewCommentDiscard.rewriting.title)
        #expect(ReviewCommentDiscard.writing.message != ReviewCommentDiscard.rewriting.message)
        #expect(ReviewCommentDiscard.writing.cancelLabel != ReviewCommentDiscard.rewriting.cancelLabel)
        #expect(ReviewCommentDiscard.writing.confirmLabel == ReviewCommentDiscard.rewriting.confirmLabel)
    }

    @Test("every question is a question")
    func titlesAreQuestions() {
        for question in [ReviewCommentDiscard.writing, .rewriting] {
            #expect(question.title.hasSuffix("?"))
            #expect(!question.message.isEmpty)
        }
    }
}
