import Testing
@testable import Core

@Suite("A selection across one answer")
struct MarkdownSelectionCopyTests {
    private func pieces(_ markdown: String) -> [MarkdownPiece] {
        MarkdownPieces.flatten(MarkdownParser.parse(markdown))
    }

    private func whole(_ texts: [String]) -> [MarkdownSelectedPiece] {
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
        #expect(MarkdownSelectionCopy.text(of: whole(["One.", "Two."]), in: flat) == "One.\n\nTwo.")
    }

    @Test("A tight list copies its markers on consecutive lines")
    func tightList() {
        let flat = pieces("- one\n- two")
        #expect(flat.map(\.marker) == [.bullet, .bullet])
        #expect(flat[1].gap == .tightItem)
        #expect(MarkdownSelectionCopy.text(of: whole(["one", "two"]), in: flat) == "\u{2022} one\n\u{2022} two")
    }

    @Test("A numbered list starts where the answer started it")
    func numberedStart() {
        let flat = pieces("3. three\n4. four")
        #expect(flat.map(\.marker) == [.number(3), .number(4)])
        #expect(MarkdownSelectionCopy.text(of: whole(["three", "four"]), in: flat) == "3. three\n4. four")
    }

    @Test("A loose list keeps a blank line between its items")
    func looseList() {
        let flat = pieces("- one\n\n- two")
        #expect(flat[1].gap == .looseItem)
        #expect(MarkdownSelectionCopy.text(of: whole(["one", "two"]), in: flat) == "\u{2022} one\n\n\u{2022} two")
    }

    @Test("A nested item is indented under its parent")
    func nestedList() {
        let flat = pieces("- one\n  - inner")
        #expect(flat.map(\.listDepth) == [1, 2])
        #expect(MarkdownSelectionCopy.text(of: whole(["one", "inner"]), in: flat) == "\u{2022} one\n  \u{2022} inner")
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
        #expect(MarkdownSelectionCopy.text(of: whole(["done", "open"]), in: flat) == "\u{2713} done\n\u{25A1} open")
    }

    @Test("Table cells copy tab separated by row")
    func table() {
        let flat = pieces("| A | B |\n| --- | --- |\n| 1 | 2 |")
        #expect(flat.count == 4)
        #expect(flat[0].root == flat[3].root)
        #expect(MarkdownSelectionCopy.text(of: whole(["A", "B", "1", "2"]), in: flat) == "A\tB\n1\t2")
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
        #expect(MarkdownSelectionCopy.text(of: whole(["One.", "\u{00A0}", "Two."]), in: flat) == "One.\n\nTwo.")
    }

    @Test("Quote pieces share the quote they belong to and copy as plain text")
    func quote() {
        let flat = pieces("> one\n>\n> two\n\n> three")
        #expect(flat[0].quotes == flat[1].quotes)
        #expect(!flat[0].quotes.isEmpty)
        #expect(flat[2].quotes.count == 1)
        #expect(flat[2].quotes != flat[0].quotes)
        #expect(MarkdownSelectionCopy.text(of: whole(["one", "two"]), in: Array(flat.prefix(2))) == "one\n\ntwo")
    }

    @Test("Pieces of one top-level block share a root, so a live tail replaces the block whole")
    func roots() {
        let flat = pieces("Intro.\n\n- one\n- two\n\nEnd.")
        #expect(flat.map(\.root) == [0, 1, 1, 2])
    }

    @Test("A selection reaches the quote formatter as it does from a single block")
    func quoteFormatter() {
        let flat = pieces("One.\n\n- two")
        let copied = MarkdownSelectionCopy.text(of: whole(["One.", "two"]), in: flat)
        #expect(SelectionQuote.quote(copied) == "> One.\n>\n> \u{2022} two")
    }

    @Test("Code in an item indents its lines but not its blank ones")
    func codeInItemCopied() {
        let flat = pieces("- ```\n  x\n\n  y\n  ```")
        let copied = MarkdownSelectionCopy.text(of: whole(["", "x\n\ny"]), in: flat)
        #expect(copied == "\u{2022} \n\n  x\n\n  y")
    }

    @Test("A selection starting inside code in an item keeps the code's lines level")
    func partialCodeInItem() {
        let flat = pieces("- ```\n  x\n  y\n  ```")
        let selected = [MarkdownSelectedPiece(index: 1, includesMarker: false, text: "x\ny")]
        #expect(MarkdownSelectionCopy.text(of: selected, in: flat) == "x\ny")
    }

    @Test("A table in an item indents only the first cell of each row")
    func tableInItem() {
        let flat = pieces("- | A | B |\n  | --- | --- |\n  | 1 | 2 |")
        #expect(flat[0].marker == .bullet)
        let copied = MarkdownSelectionCopy.text(of: whole(["", "A", "B", "1", "2"]), in: flat)
        #expect(copied == "\u{2022} \n  A\tB\n  1\t2")
    }

    @Test("Two separate lists are separate blocks in the copy")
    func adjacentLists() {
        let flat = pieces("- a\n\n1. b")
        #expect(flat[0].root != flat[1].root)
        #expect(MarkdownSelectionCopy.text(of: whole(["a", "b"]), in: flat) == "\u{2022} a\n\n1. b")
    }

    @Test("A further paragraph in an item is indented under its marker")
    func continuation() {
        let flat = pieces("- a\n\n  b\n\n- c")
        #expect(MarkdownSelectionCopy.text(of: whole(["a", "b", "c"]), in: flat) == "\u{2022} a\n\n  b\n\n\u{2022} c")
    }

    @Test("A soft break inside an item copies as a line under the item")
    func softBreak() {
        let flat = pieces("- first  \n  second")
        let copied = MarkdownSelectionCopy.text(of: whole(["first" + MarkdownSelectionCopy.softBreak + "second"]), in: flat)
        #expect(copied == "\u{2022} first\n  second")
    }

    @Test("Numbering is counted from the list's start, not read from each line")
    func numberingIsCounted() {
        let flat = pieces("5. a\n9. b")
        #expect(flat.map(\.marker) == [.number(5), .number(6)])
    }

    @Test("An empty quote in an item keeps the bullet on the item and off the next paragraph")
    func emptyQuoteInItem() {
        let flat = MarkdownPieces.flatten([
            .bulletList(items: [[.blockQuote(blocks: [])]], tight: true),
            .paragraph(inline: [.text("Next")]),
        ])
        #expect(flat[0].marker == .bullet)
        #expect(flat[1].marker == nil)
        #expect(flat[1].listDepth == 0)
    }

    @Test("A rule in an item leaves its marker on a line of its own")
    func ruleInItem() {
        let flat = MarkdownPieces.flatten([.bulletList(items: [[.thematicBreak]], tight: true)])
        #expect(flat[0].marker == .bullet)
        #expect(flat[1].body == .rule)
    }

    @Test("A list inside an item keeps both markers")
    func listAsFirstThingInItem() {
        let flat = MarkdownPieces.flatten([
            .bulletList(items: [[.bulletList(items: [[.paragraph(inline: [.text("a")])]], tight: true)]], tight: true),
        ])
        #expect(flat.map(\.marker) == [.bullet, .bullet])
        #expect(flat.map(\.listDepth) == [1, 2])
    }

    @Test("A row shorter than its headers still fills every column")
    func shortRow() {
        let flat = MarkdownPieces.flatten([
            .table(headers: [[.text("A")], [.text("B")]], rows: [[[.text("1")]]], alignments: []),
        ])
        #expect(flat.count == 4)
        guard case let .cell(last) = flat[3].body else {
            Issue.record("the last piece is not a cell")
            return
        }
        #expect(last.inline.isEmpty)
        #expect(last.alignment == .leading)
    }

    @Test("Two tables stay two tables in the copy, and a selection can start mid row")
    func tableBoundaries() {
        let flat = pieces("| A |\n| --- |\n| 1 |\n\n| B |\n| --- |\n| 2 |")
        guard case let .cell(first) = flat[0].body, case let .cell(second) = flat[2].body else {
            Issue.record("the pieces are not cells")
            return
        }
        #expect(first.table != second.table)
        let copied = MarkdownSelectionCopy.text(of: [
            MarkdownSelectedPiece(index: 1, includesMarker: false, text: "1"),
            MarkdownSelectedPiece(index: 2, includesMarker: false, text: "B"),
        ], in: flat)
        #expect(copied == "1\n\nB")
    }

    @Test("A list does not leak its depth into what follows it")
    func contextIsRestored() {
        let flat = pieces("- a\n  - b\n- c\n\nEnd.")
        #expect(flat.map(\.listDepth) == [1, 2, 1, 0])
        #expect(flat[3].marker == nil)
    }

    @Test("Joiners that are part of the text survive the copy")
    func joinersSurvive() {
        let flat = pieces("One.")
        let family = "\u{1F468}\u{200D}\u{1F469}"
        let persian = "\u{0645}\u{06CC}\u{200C}\u{062E}"
        #expect(MarkdownSelectionCopy.text(of: whole([family + persian]), in: flat) == family + persian)
    }

    @Test("A selection with no usable pieces copies nothing")
    func emptySelection() {
        let flat = pieces("One.")
        #expect(MarkdownSelectionCopy.text(of: [], in: flat).isEmpty)
        #expect(MarkdownSelectionCopy.text(of: [MarkdownSelectedPiece(index: 9, includesMarker: false, text: "x")], in: flat).isEmpty)
    }
}
