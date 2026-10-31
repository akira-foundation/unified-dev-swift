import Testing
@testable import Core

@Suite("Issue reference detection")
struct LinkScanIssueReferenceTests {
    private func written(_ text: String) -> [String] {
        LinkScan.links(in: text).map(\.text)
    }

    private func addresses(_ text: String) -> [String] {
        LinkScan.links(in: text).map(\.url)
    }

    @Test("an owner, a repository and a number open that issue on GitHub")
    func reference() {
        let sentence = "Issue criada: kriol-lang/kriol#31. A criar a branch."
        #expect(written(sentence) == ["kriol-lang/kriol#31"])
        #expect(addresses(sentence) == ["https://github.com/kriol-lang/kriol/issues/31"])
    }

    @Test("a repository name keeps its dots and underscores", arguments: [
        "akira-io/unified.dev#7", "akira-io/my_repo#7", "A1/b-c#123456", "a/b#123456789", "vercel/next.js#123",
        "\(String(repeating: "o", count: 39))/\(String(repeating: "r", count: 100))#123456789",
    ])
    func repositoryCharacters(reference: String) {
        #expect(written("see \(reference) now") == [reference])
    }

    @Test("the range covers the reference and nothing around it")
    func rangeIsExact() throws {
        let sentence = "(fixed in akira-io/ui#12)"
        let link = try #require(LinkScan.links(in: sentence).first)
        #expect(String(sentence[link.range]) == "akira-io/ui#12")
    }

    @Test("punctuation after the number belongs to the sentence", arguments: [".", ",", ";", ":", "!", "?", ")"])
    func trailingPunctuation(mark: String) {
        #expect(written("closed a/b#9\(mark)") == ["a/b#9"])
    }

    @Test("a reference glued to more text is not a reference", arguments: [
        "a/b#9x", "a/b#9_", "a/b#9-1", "a/b#9/c", "a/b#9#2", "a/b#9.5", "a/b#9@c",
        "x.a/b#9", "x/a/b#9", "@a/b#9", "-a/b#9", "a-/b#9", "a/b#9.md", "a/b#9+", "a/b#9~", "a/b#9%",
        "a_b/c#3", "a/b#9\u{0663}", "\u{00E1}/b#3",
    ])
    func glued(fragment: String) {
        #expect(written("ran \(fragment) today").isEmpty)
    }

    @Test("a path with an anchor, a lone hash or a missing part is not a reference", arguments: [
        "Sources/Core/Model.swift#L10", "a/b#", "a/b#L3", "a/#3", "/b#3", "a/b#0", "a/..#3", "#31",
        "feature/branch-name", "a/b #3", "a/b#01", "a/.#3", "akira-io/unifieddev.git#3",
        "\(String(repeating: "o", count: 40))/b#3", "a/\(String(repeating: "r", count: 101))#3", "a/b#1234567890",
    ])
    func notReferences(fragment: String) {
        #expect(written("see \(fragment) here").isEmpty)
    }

    @Test("a GitHub address is one link, not an address and a reference")
    func insideAddress() {
        #expect(written("https://github.com/kriol-lang/kriol#31") == ["https://github.com/kriol-lang/kriol#31"])
    }

    @Test("a reference inside a code span is being quoted, not offered")
    func codeSpan() {
        #expect(written("run `gh issue view kriol-lang/kriol#31` then kriol-lang/kriol#32")
            == ["kriol-lang/kriol#32"])
    }

    @Test("an issue reference in markdown becomes a link to that issue")
    func markdown() {
        #expect(MarkdownParser.parse("Issue criada: **kriol-lang/kriol#31**.") == [
            .paragraph(inline: [
                .text("Issue criada: "),
                .strong([.link(text: [.text("kriol-lang/kriol#31")], url: "https://github.com/kriol-lang/kriol/issues/31")]),
                .text("."),
            ]),
        ])
    }

    @Test("a reference that is the label of a link is not a second link")
    func linkLabel() {
        let pull = "https://github.com/akira-io/ui/pull/12"
        #expect(MarkdownParser.parse("see [akira-io/ui#12](\(pull)) and [**https://a.test**](\(pull))") == [
            .paragraph(inline: [
                .text("see "),
                .link(text: [.text("akira-io/ui#12")], url: pull),
                .text(" and "),
                .link(text: [.strong([.text("https://a.test")])], url: pull),
            ]),
        ])
        #expect(LinkPolicy.addresses(in: MarkdownParser.parse("[akira-io/ui#12](\(pull))")) == [pull])
    }

    @Test("a link label keeps its own emphasis and runs its text together once inner links are gone")
    func linkLabelShapes() {
        #expect(MarkdownParser.parse("[a *https://a.test* ~~a/b#1~~ b https://b.test c](https://u.test)") == [
            .paragraph(inline: [
                .link(text: [
                    .text("a "),
                    .emphasis([.text("https://a.test")]),
                    .text(" "),
                    .strikethrough([.text("a/b#1")]),
                    .text(" b https://b.test c"),
                ], url: "https://u.test"),
            ]),
        ])
    }

    @Test("a label whose own target opens nothing keeps the links inside it")
    func inertLinkLabel() {
        #expect(MarkdownParser.parse("[https://docs.test/a](notes) ") == [
            .paragraph(inline: [
                .link(text: [.link(text: [.text("https://docs.test/a")], url: "https://docs.test/a")], url: "notes"),
                .text(" "),
            ]),
        ])
    }

    @Test("every prefix of a reference scans")
    func everyPrefixScans() {
        let text = "kriol-lang/kriol#31."
        for length in 0...text.count {
            _ = LinkScan.links(in: String(text.prefix(length)))
        }
    }
}
