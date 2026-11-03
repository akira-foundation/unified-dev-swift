import Testing
@testable import Core

@Suite("Canvas markdown page", .tags(.security))
struct CanvasMarkdownPageTests {
    private func page(_ source: String) -> String {
        CanvasMarkdownPage.html(from: source, title: "t")
    }

    @Test("the parser reads an image as a bang before a link")
    func parserReadsImage() {
        let blocks = MarkdownParser.parse("![alt](img/a.png)")
        guard case let .paragraph(inline) = blocks.first, inline.count == 2,
              case let .text(before) = inline[0]
        else {
            Issue.record("unexpected shape \(blocks)")
            return
        }
        #expect(before.hasSuffix("!"))
        #expect(inline[1] == .link(text: [.text("alt")], url: "img/a.png"))
    }

    @Test("headings, emphasis, lists, tables and code become their elements")
    func elements() {
        let html = page("# T\n\n**b**\n\n- a\n\n| x | y |\n|---|---|\n| 1 | 2 |\n\n```\ncode\n```")
        #expect(html.contains("<h1>T</h1>"))
        #expect(html.contains("<strong>b</strong>"))
        #expect(html.contains("<ul><li>"))
        #expect(html.contains("<table>"))
        #expect(html.contains("<th>"))
        #expect(html.contains("<pre><code"))
    }

    @Test("an image becomes an img with its alt")
    func image() {
        let html = page("![alt](img/a.png)")
        #expect(html.contains("<img src=\"img/a.png\" alt=\"alt\">"))
        #expect(!html.contains("!<a"))
    }

    @Test("raw html is shown as text, never as markup", arguments: [
        "<script>alert(1)</script>", "<img src=x onerror=alert(1)>"
    ])
    func rawHTML(source: String) {
        let html = page(source)
        #expect(!html.contains("<script"))
        #expect(!html.contains("<img src=x"))
        #expect(html.contains("&lt;script&gt;") || html.contains("&lt;img"))
    }

    @Test("a dangerous address is not linked", arguments: [
        "javascript:alert(1)", "JaVaScRiPt:alert(1)", "data:text/html,<b>x</b>", "vbscript:x",
        " javascript:alert(1)", "java\tscript:alert(1)",
        "java\nscript:alert(1)", "\u{0}javascript:alert(1)"
    ])
    func dangerous(address: String) {
        let linked = page("[visible](\(address))")
        #expect(!linked.contains("href="))
        #expect(linked.contains("visible"))
        let pictured = page("![visible](\(address))")
        #expect(!pictured.contains("src="))
        #expect(pictured.contains("visible"))
    }

    @Test("relative, http, https and mailto addresses are linked", arguments: [
        "docs/a.md", "http://x.test", "HTTPS://x.test", "mailto:a@b.test", "#top"
    ])
    func safe(address: String) {
        #expect(page("[go](\(address))").contains("<a href=\""))
    }

    @Test("an html entity cannot rebuild a scheme")
    func entityScheme() {
        let html = page("[x](javascript&#58;alert(1))")
        #expect(!html.contains("href=\"javascript:"))
        #expect(html.contains("&amp;#58;"))
    }

    @Test("an address keeps its spaces encoded and loses its title")
    func spacesAndTitles() {
        #expect(page("[x](my file.md)").contains("href=\"my%20file.md\""))
        #expect(page("[x](a.png \"t\")").contains("href=\"a.png\""))
    }

    @Test("an alt cannot break out of its attribute")
    func altEscaped() {
        let html = page("![a\" onerror=\"x](i.png)")
        #expect(!html.contains("\" onerror="))
        #expect(html.contains("&quot; onerror=&quot;"))
    }

    @Test("a code fence info string cannot break out of its attribute")
    func infoEscaped() {
        let html = page("```js\"onload=\"x\ncode\n```")
        #expect(html.contains("&quot;"))
        #expect(!html.contains("\"onload="))
    }

    @Test("an address check refuses hidden schemes and keeps safe ones")
    func safeAddressDirect() {
        for hidden in ["java\nscript:alert(1)", "\u{0}javascript:alert(1)", " javascript:alert(1)", "java\tscript:alert(1)"] {
            #expect(CanvasMarkdownPage.safeAddress(hidden) == nil)
        }
        #expect(CanvasMarkdownPage.safeAddress("docs/a.png") == "docs/a.png")
        #expect(CanvasMarkdownPage.safeAddress("https://x.test/a") == "https://x.test/a")
    }

    @Test("a parenthesis in an address is not a title")
    func parenthesisKept() {
        #expect(CanvasMarkdownPage.safeAddress("my (1).md") == "my%20(1).md")
        #expect(CanvasMarkdownPage.safeAddress("a.png \"t\"") == "a.png")
    }

    @Test("code inside a block is escaped")
    func codeEscaped() {
        #expect(page("```html\n<b>x</b>\n```").contains("&lt;b&gt;"))
    }

    @Test("the title is escaped")
    func titleEscaped() {
        #expect(CanvasMarkdownPage.html(from: "", title: "<x>").contains("<title>&lt;x&gt;</title>"))
    }

    @Test("only md and markdown files are markdown")
    func extensions() {
        #expect(CanvasMarkdownPage.isMarkdown(path: "a/README.md"))
        #expect(CanvasMarkdownPage.isMarkdown(path: "NOTES.MARKDOWN"))
        #expect(!CanvasMarkdownPage.isMarkdown(path: "a.html"))
        #expect(!CanvasMarkdownPage.isMarkdown(path: "md"))
    }
}
