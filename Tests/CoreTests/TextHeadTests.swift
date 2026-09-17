import Testing
import Foundation
@testable import Core

@Suite("Text head")
struct TextHeadTests {
    @Test("nothing to show answers nothing")
    func emptyTextHasNoHead() {
        #expect(TextHead.head(of: "") == nil)
        #expect(TextHead.head(of: "\n\n   \n") == nil)
    }

    @Test("a short text is itself, whole")
    func shortTextIsWhole() throws {
        let head = try #require(TextHead.head(of: "one\ntwo\n"))
        #expect(head.lines == ["one", "two"])
        #expect(!head.truncated)
    }

    @Test("a long text is cut and says so")
    func longTextIsCut() throws {
        let text = (1...40).map(String.init).joined(separator: "\n")
        let head = try #require(TextHead.head(of: text, lines: 3))
        #expect(head.lines == ["1", "2", "3"])
        #expect(head.truncated)
    }

    @Test("a long line is cut with an ellipsis rather than wrapped")
    func longLinesAreCut() throws {
        let head = try #require(TextHead.head(of: String(repeating: "x", count: 20), columns: 8))
        #expect(head.lines == [String(repeating: "x", count: 8) + "\u{2026}"])
        #expect(!head.truncated)
    }

    @Test("a tab is four spaces")
    func tabsAreExpanded() throws {
        let head = try #require(TextHead.head(of: "\tindented"))
        #expect(head.lines == ["    indented"])
    }
}
