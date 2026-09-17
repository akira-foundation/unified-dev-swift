import Testing
@testable import Core

@Suite("Review comment edit")
struct ReviewCommentEditTests {
    @Test("saves the trimmed text")
    func savesTrimmed() {
        #expect(
            ReviewCommentEdit.outcome(typed: "  this is wrong\n", replacing: "old")
                == .save("this is wrong")
        )
    }

    @Test("keeps the line breaks inside a multi-line comment")
    func keepsInteriorBreaks() {
        let typed = "\n first line\nsecond line\n\n"

        #expect(
            ReviewCommentEdit.outcome(typed: typed, replacing: "old")
                == .save("first line\nsecond line")
        )
    }

    @Test("refuses an empty edit rather than reading it as a deletion", arguments: [
        "", "   ", "\n", " \t\n ",
    ])
    func refusesEmpty(typed: String) {
        #expect(ReviewCommentEdit.outcome(typed: typed, replacing: "old") == .refused)
        #expect(!ReviewCommentEdit.canSubmit(typed))
    }

    @Test("writes nothing when the text says what the comment already says")
    func unchanged() {
        #expect(ReviewCommentEdit.outcome(typed: "same", replacing: "same") == .unchanged)
        #expect(ReviewCommentEdit.outcome(typed: " same \n", replacing: "same") == .unchanged)
    }

    @Test("offers the confirm control for anything with a character in it")
    func canSubmit() {
        #expect(ReviewCommentEdit.canSubmit("a"))
        #expect(ReviewCommentEdit.canSubmit("  a  "))
        #expect(ReviewCommentEdit.canSubmit("line\nline"))
    }

    @Test("tidies a stored body that carries whitespace")
    func tidiesStoredEdges() {
        #expect(ReviewCommentEdit.outcome(typed: "note", replacing: "note ") == .save("note"))
    }
}
