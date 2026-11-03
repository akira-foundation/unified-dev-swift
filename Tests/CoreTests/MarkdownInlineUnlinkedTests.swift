import Testing
@testable import Core

@Suite("A link's label with the links taken out")
struct MarkdownInlineUnlinkedTests {
    @Test("a link becomes its label, joined to the text beside it")
    func aLinkBecomesText() {
        let inline: [MarkdownInline] = [
            .text("see "), .link(text: [.text("the docs")], url: "https://example.com"), .text(" now"),
        ]

        #expect(inline.unlinked == [.text("see the docs now")])
    }

    @Test("a link inside emphasis, strong or strikethrough goes and the styling stays")
    func stylingSurvives() {
        let link = MarkdownInline.link(text: [.text("x")], url: "https://example.com")

        #expect([MarkdownInline.emphasis([link])].unlinked == [.emphasis([.text("x")])])
        #expect([MarkdownInline.strong([link])].unlinked == [.strong([.text("x")])])
        #expect([MarkdownInline.strikethrough([link])].unlinked == [.strikethrough([.text("x")])])
    }

    @Test("a link inside a link goes all the way down")
    func nestedLinks() {
        let inner = MarkdownInline.link(text: [.text("inner")], url: "https://inner.example")
        let outer = MarkdownInline.link(text: [.text("a "), inner], url: "https://outer.example")

        #expect([outer].unlinked == [.text("a inner")])
    }

    @Test("code and line breaks are left as they are, and keep text apart")
    func codeAndBreaksStay() {
        let inline: [MarkdownInline] = [.text("a"), .code("b"), .lineBreak, .text("c")]

        #expect(inline.unlinked == inline)
    }
}
