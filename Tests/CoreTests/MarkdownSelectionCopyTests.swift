import Testing
@testable import Core

@Suite("A selection across one answer")
struct MarkdownSelectionCopyTests {
    private func pieces(_ markdown: String) -> [MarkdownPiece] {
        MarkdownPieces.flatten(MarkdownParser.parse(markdown))
    }

    private func whole(_ pieces: [MarkdownPiece], _ texts: [String]) -> [MarkdownSelectedPiece] {
        texts.enumerated().map { MarkdownSelectedPiece(index: $0.offset, includesMarker: true, text: $0.element) }
    }

    @Test("Each block of an answer becomes its own piece in reading order")
    func readingOrder() {
        let flat = pieces("# Title\n\nFirst.\n\n```swift\nlet a = 1\n```\n\n---\n\nLast.")
        #expect(flat.count == 5)
        #expect(flat[0].body == .text([.text("Title")], heading: 1))
        #expect(flat[1].gap == .block)
        guard case let .code(code, _, _) = flat[2].body else {
            Issue.record("the third piece is not the code block")
            return
        }
        #expect(code == "let a = 1")
        #expect(flat[3].body == .rule)
    }

    @Test("A heading after a block gets the wider gap and a first heading gets none")
    func headingGaps() {
        let flat = pieces("# One\n\nProse.\n\n## Two")
        #expect(flat[0].gap == .none)
        #expect(flat[2].gap == .heading)
    }

    @Test("Paragraphs copy with a blank line between them")
    func paragraphs() {
        let flat = pieces("One.\n\nTwo.")
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["One.", "Two."]), in: flat) == "One.\n\nTwo.")
    }

    @Test("A tight list copies its markers on consecutive lines")
    func tightList() {
        let flat = pieces("- one\n- two")
        #expect(flat.map(\.marker) == [.bullet, .bullet])
        #expect(flat[1].gap == .tightItem)
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["one", "two"]), in: flat) == "\u{2022} one\n\u{2022} two")
    }

    @Test("A numbered list starts where the answer started it")
    func numberedStart() {
        let flat = pieces("3. three\n4. four")
        #expect(flat.map(\.marker) == [.number(3), .number(4)])
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["three", "four"]), in: flat) == "3. three\n4. four")
    }

    @Test("A loose list keeps a blank line between its items")
    func looseList() {
        let flat = pieces("- one\n\n- two")
        #expect(flat[1].gap == .looseItem)
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["one", "two"]), in: flat) == "\u{2022} one\n\n\u{2022} two")
    }

    @Test("A nested item is indented under its parent")
    func nestedList() {
        let flat = pieces("- one\n  - inner")
        #expect(flat.map(\.listDepth) == [1, 2])
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["one", "inner"]), in: flat) == "\u{2022} one\n  \u{2022} inner")
    }

    @Test("A selection starting inside an item drops the marker it never reached")
    func partialItem() {
        let flat = pieces("- first item\n- second")
        let selected = [
            MarkdownSelectedPiece(index: 0, includesMarker: false, text: "item"),
            MarkdownSelectedPiece(index: 1, includesMarker: true, text: "second"),
        ]
        #expect(MarkdownSelectionCopy.text(of: selected, in: flat) == "item\n\u{2022} second")
    }

    @Test("Task items copy their state")
    func tasks() {
        let flat = pieces("- [x] done\n- [ ] open")
        #expect(flat[1].gap == .task)
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["done", "open"]), in: flat) == "\u{2713} done\n\u{25A1} open")
    }

    @Test("Table cells copy tab separated by row")
    func table() {
        let flat = pieces("| A | B |\n| --- | --- |\n| 1 | 2 |")
        #expect(flat.count == 4)
        #expect(flat[0].root == flat[3].root)
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["A", "B", "1", "2"]), in: flat) == "A\tB\n1\t2")
    }

    @Test("A code block keeps its lines and is not wrapped by the copy")
    func code() {
        let source = "let a = 1\nlet b = 2"
        let flat = pieces("Before.\n\n```\n\(source)\n```")
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["Before.", source]), in: flat) == "Before.\n\n\(source)")
    }

    @Test("A code block as the first thing in an item leaves its marker a line of its own")
    func codeInItem() {
        let flat = pieces("- ```\n  x\n  ```")
        #expect(flat[0].marker == .bullet)
        #expect(flat[0].body == .text([], heading: nil))
        guard case .code = flat[1].body else {
            Issue.record("the second piece is not the code block")
            return
        }
        #expect(flat[1].gap == .block)
    }

    @Test("A rule is never copied")
    func rule() {
        let flat = pieces("One.\n\n---\n\nTwo.")
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["One.", "\u{00A0}", "Two."]), in: flat) == "One.\n\nTwo.")
    }

    @Test("Quote pieces share the quote they belong to and copy as plain text")
    func quote() {
        let flat = pieces("> one\n>\n> two\n\n> three")
        #expect(flat[0].quotes == flat[1].quotes)
        #expect(!flat[0].quotes.isEmpty)
        #expect(MarkdownSelectionCopy.text(of: whole(flat, ["one", "two"]), in: Array(flat.prefix(2))) == "one\n\ntwo")
    }

    @Test("Pieces of one top-level block share a root, so a live tail replaces the block whole")
    func roots() {
        let flat = pieces("Intro.\n\n- one\n- two\n\nEnd.")
        #expect(flat.map(\.root) == [0, 1, 1, 2])
    }

    @Test("A selection reaches the quote formatter as it does from a single block")
    func quoteFormatter() {
        let flat = pieces("One.\n\n- two")
        let copied = MarkdownSelectionCopy.text(of: whole(flat, ["One.", "two"]), in: flat)
        #expect(SelectionQuote.quote(copied) == "> One.\n>\n> \u{2022} two")
    }
}
