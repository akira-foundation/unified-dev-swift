import Foundation
import Testing
@testable import Core

@Suite("Markdown as plain text")
struct MarkdownPlainTextTests {
    @Test("A heading loses its hashes and keeps its words")
    func headings() {
        #expect(MarkdownPlainText.render("### Features") == "Features")
        #expect(MarkdownPlainText.render("# One\n\n## Two") == "One\n\nTwo")
    }

    @Test("A bullet list is marked with bullets, and a nested one is indented")
    func bulletLists() {
        let rendered = MarkdownPlainText.render("- first\n- second\n  - nested")

        #expect(rendered == "\u{2022} first\n\u{2022} second\n  \u{2022} nested")
    }

    @Test("A numbered list counts from where it started")
    func numberedLists() {
        #expect(MarkdownPlainText.render("3. third\n7. fourth") == "3. third\n4. fourth")
    }

    @Test("Emphasis, strong and code lose their markers")
    func inlineMarkers() {
        #expect(MarkdownPlainText.render("*(updates)* a **third** button for `codesign`")
            == "(updates) a third button for codesign")
    }

    @Test("A link keeps its words and says where it goes")
    func links() {
        #expect(MarkdownPlainText.render("the [release page](https://example.invalid/r)")
            == "the release page (https://example.invalid/r)")
        #expect(MarkdownPlainText.render("<https://example.invalid/r>") == "https://example.invalid/r")
    }

    @Test("A fenced block keeps its lines and loses its fence")
    func codeBlocks() {
        #expect(MarkdownPlainText.render("```sh\nmake build\nmake lint\n```") == "make build\nmake lint")
    }

    @Test("A task list says what is done")
    func taskLists() {
        #expect(MarkdownPlainText.render("- [x] done\n- [ ] not yet")
            == "\u{2713} done\n\u{25A1} not yet")
    }

    @Test("A table reads as rows, and a rule reads as nothing")
    func tablesAndRules() {
        #expect(MarkdownPlainText.render("| a | b |\n| --- | --- |\n| 1 | 2 |") == "a  b\n1  2")
        #expect(MarkdownPlainText.render("one\n\n---\n\ntwo") == "one\n\ntwo")
    }

    @Test("A quote keeps its words and loses the angle bracket")
    func quotes() {
        #expect(MarkdownPlainText.render("> careful here") == "careful here")
    }

    @Test("Nothing in means nothing out, however much whitespace arrives")
    func emptyInput() {
        #expect(MarkdownPlainText.render("").isEmpty)
        #expect(MarkdownPlainText.render("   \n\n \t \n").isEmpty)
    }

    @Test("A real release body keeps its shape and loses every marker")
    func releaseBody() {
        let rendered = MarkdownPlainText.render("""
            ### Features

            - *(updates)* carry the notes
            - *(sidebar)* keep every control

            ### Bug Fixes

            - quote a branch with a slash
            """)

        #expect(rendered == """
            Features

            \u{2022} (updates) carry the notes
            \u{2022} (sidebar) keep every control

            Bug Fixes

            \u{2022} quote a branch with a slash
            """)
    }

    @Test("A line break inside a list item keeps the item's indent")
    func lineBreakInsideAnItem() {
        #expect(MarkdownPlainText.render("- quoted  \n  before git\n- the next one")
            == "\u{2022} quoted\n  before git\n\u{2022} the next one")
    }

    @Test("A fenced block under a bullet keeps every line in the same column")
    func codeBlockInsideAnItem() {
        let rendered = MarkdownPlainText.render("- ```\n      a\n      b\n  ```")

        #expect(rendered == "\u{2022}     a\n      b")
    }

    @Test("A loose list keeps the blank line that makes its items two paragraphs")
    func looseList() {
        let rendered = MarkdownPlainText.render("- First.\n\n  Second, same item.\n\n- Next item.")

        #expect(rendered == "\u{2022} First.\n\n  Second, same item.\n\n\u{2022} Next item.")
    }

    @Test("Control characters and the marks that reorder text never reach the alert")
    func stripsControlCharacters() {
        let hostile = "Install\u{202E}llatsnI\u{200F} now\u{0007}\u{2028}and again\u{FEFF}"

        #expect(MarkdownPlainText.render(hostile) == "InstallllatsnI nowand again")
        #expect(MarkdownPlainText.render("`\u{202E}code`") == "code")
        #expect(MarkdownPlainText.render("[see](https://e.invalid/\u{202E}x)")
            == "see (https://e.invalid/x)")
    }
}
