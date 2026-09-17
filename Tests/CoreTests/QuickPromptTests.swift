import Testing
import Foundation
@testable import Core

@Suite("Quick prompts")
struct QuickPromptTests {
    static func prompt(
        _ name: String, _ text: String, symbol: String = QuickPrompt.defaultSymbol
    ) -> QuickPrompt {
        QuickPrompt(name: name, symbol: symbol, text: text)
    }

    static let insertions: [(draft: String, prompt: String, expected: String)] = [
        ("|", "Run the tests", "Run the tests|"),
        ("Take my side.|", "Run the tests", "Take my side. Run the tests|"),
        ("fix the bu|", "Run the tests", "fix the bu Run the tests|"),
        ("and then |", "Run the tests", "and then Run the tests|"),
        ("first line\n|", "Run the tests", "first line\nRun the tests|"),
        ("first line\n\n|", "Run the tests", "first line\n\nRun the tests|"),
        ("before |after", "Run the tests", "before Run the tests| after"),
        ("|already typed", "Run the tests", "Run the tests| already typed"),
        ("|", "One\nTwo", "One\nTwo|"),
        ("done.|", "  Run the tests\n", "done. Run the tests|"),
    ]

    @Test("Inserting a prompt spaces it and leaves the caret after it")
    func inserts() {
        for row in Self.insertions {
            let (draft, caret) = Self.split(row.draft)
            let result = QuickPromptInsertion.inserting(row.prompt, into: draft, at: caret)
            let (expected, expectedCaret) = Self.split(row.expected)
            #expect(result.text == expected, "draft \(row.draft)")
            #expect(result.caret == expectedCaret, "draft \(row.draft)")
        }
    }

    @Test("A caret outside the draft is clamped rather than trusted")
    func clampsCaret() {
        let far = QuickPromptInsertion.inserting("go", into: "abc", at: 99)
        #expect(far.text == "abc go")
        #expect(far.caret == 6)

        let negative = QuickPromptInsertion.inserting("go", into: "abc", at: -4)
        #expect(negative.text == "go abc")
        #expect(negative.caret == 2)
    }

    @Test("A prompt with nothing in it changes nothing")
    func emptyPrompt() {
        let result = QuickPromptInsertion.inserting("   \n ", into: "abc", at: 1)
        #expect(result.text == "abc")
        #expect(result.caret == 1)
    }

    @Test("Offsets are UTF-16 units")
    func utf16Offsets() {
        let draft = "\u{1F41E}"
        let result = QuickPromptInsertion.inserting("go", into: draft, at: (draft as NSString).length)
        #expect(result.text == "\u{1F41E} go")
        #expect(result.caret == 5)
    }

    @Test("A prompt inserts through its value as well as through its text")
    func insertsFromValue() {
        let prompt = Self.prompt("Tests", "Run the tests")
        let result = QuickPromptInsertion.inserting(prompt, into: "go.", at: 3)
        #expect(result.text == "go. Run the tests")
    }

    static func split(_ marked: String) -> (String, Int) {
        let parts = marked.components(separatedBy: "|")
        let caret = (parts[0] as NSString).length
        return (parts.joined(), caret)
    }

    static let list: [QuickPrompt] = [
        prompt("Run the tests and fix what fails", "Run make test. If anything fails, fix it."),
        prompt("Open a pull request", "Push the branch and open a PR. Three sentences."),
        prompt("Review the diff", "Read it cold, and say which parts have no tests."),
    ]

    @Test("An empty query is the list itself, in order")
    func emptyQuery() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "")
        #expect(matches.prompts.map(\.name) == Self.list.map(\.name))
        #expect(matches.query.isEmpty)
        #expect(!matches.isEmpty)
    }

    @Test("The query matches the name and the text")
    func matchesNameAndText() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "test")
        #expect(matches.prompts.count == 2)
        #expect(matches.prompts[0].name == "Run the tests and fix what fails")
        #expect(matches.prompts[1].name == "Review the diff")
    }

    @Test("A query nothing carries keeps nothing")
    func matchesNothing() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "deploy")
        #expect(matches.isEmpty)
        #expect(matches.query == "deploy")
    }

    @Test("A subsequence of the body alone is not a match")
    func bodyIsNotFuzzy() {
        let paragraph = Self.prompt("Anything", "Read the diff cold and say what you would change.")
        #expect(FuzzyMatch.score(paragraph.text, query: "dye") != nil)
        #expect(QuickPromptMatches.ranking([paragraph], query: "dye").isEmpty)
    }

    @Test("The name is matched loosely, out of order characters and all")
    func nameIsFuzzy() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "opnpr")
        #expect(matches.prompts.map(\.name) == ["Open a pull request"])
    }

    @Test("Search is case insensitive on both halves")
    func caseInsensitive() {
        #expect(QuickPromptMatches.ranking(Self.list, query: "REVIEW").prompts.count == 1)
        #expect(QuickPromptMatches.ranking(Self.list, query: "MAKE TEST").prompts.count == 1)
    }

    @Test("Down from nothing lands on the first row, and up on the last")
    func stepsFromNothing() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "")
        #expect(matches.stepped(from: nil, by: 1) == Self.list[0])
        #expect(matches.stepped(from: nil, by: -1) == Self.list[2])
    }

    @Test("Stepping wraps at both ends")
    func stepsWrap() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "")
        #expect(matches.stepped(from: Self.list[2], by: 1) == Self.list[0])
        #expect(matches.stepped(from: Self.list[0], by: -1) == Self.list[2])
        #expect(matches.stepped(from: Self.list[0], by: 1) == Self.list[1])
    }

    @Test("An empty list has nothing to step onto")
    func stepsNowhere() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "deploy")
        #expect(matches.stepped(from: nil, by: 1) == nil)
        #expect(matches.stepped(from: Self.list[0], by: 1) == nil)
    }

    @Test("The highlight survives a query that keeps its row, and moves when it does not")
    func settles() {
        let matches = QuickPromptMatches.ranking(Self.list, query: "test")
        #expect(matches.settled(after: Self.list[0]) == Self.list[0])
        #expect(matches.settled(after: Self.list[1]) == matches.prompts.first)
        #expect(matches.settled(after: nil) == matches.prompts.first)
    }

    @Test("An edited row is still the highlighted row")
    func settlesAfterEdit() {
        var edited = Self.list[1]
        edited.name = "Open a PR"
        let matches = QuickPromptMatches.ranking([Self.list[0], edited], query: "")
        #expect(matches.settled(after: Self.list[1]) == edited)
    }

    @Test("The preview is one line of the text, cut short")
    func preview() {
        #expect(Self.prompt("x", "One line").preview == "One line")
        #expect(Self.prompt("x", "  One\n\nTwo  ").preview == "One Two")

        let long = String(repeating: "ab ", count: 40)
        let preview = Self.prompt("x", long).preview
        #expect(preview.hasSuffix("\u{2026}"))
        #expect(preview.count <= QuickPrompt.previewLength + 1)
    }

    @Test("A prompt with no name falls back to its own words")
    func resolvedName() {
        #expect(Self.prompt("  ", "Run the tests").resolvedName == "Run the tests")
        #expect(Self.prompt(" Tests ", "Run the tests").resolvedName == "Tests")
    }

    @Test("An unknown symbol is drawn as the fallback")
    func resolvedSymbol() {
        #expect(QuickPrompt.resolvedSymbol("doc.richtext") == "doc.richtext")
        #expect(QuickPrompt.resolvedSymbol("nothing.like.this") == QuickPrompt.defaultSymbol)
        #expect(QuickPrompt.symbols.contains(QuickPrompt.defaultSymbol))
        #expect(Set(QuickPrompt.symbols).count == QuickPrompt.symbols.count)
    }

    @Test("A fresh database is offered every built-in, and a seeded one none")
    func pendingSeed() {
        #expect(QuickPromptSeed.pending(installed: 0).count == QuickPromptSeed.all.count)
        #expect(QuickPromptSeed.pending(installed: QuickPromptSeed.version).isEmpty)
    }

    @Test("Every built-in is introduced at or below the version the store records")
    func seedVersionCoversTheList() {
        for entry in QuickPromptSeed.all {
            #expect(entry.introducedIn <= QuickPromptSeed.version)
            #expect(entry.introducedIn > 0)
            #expect(QuickPrompt.symbols.contains(entry.symbol))
        }
    }

    @Test("The prompt Unified Dev ships with is the one that was asked for")
    func shippedPrompt() {
        let explain = QuickPromptSeed.all.first { $0.name == "Explain changes" }
        #expect(explain?.text == """
        Explain the changes made in this PR as HTML. Open it as a new tab in this workspace.
        """)
    }
}
