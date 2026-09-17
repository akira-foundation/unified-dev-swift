import Testing
@testable import Core

@Suite("Project monograms")
struct RepoMonogramTests {
    @Test("takes one letter from each of the first two words", arguments: [
        ("there-there", "TT"),
        ("laravel-backup", "LB"),
        ("my_app", "MA"),
        ("freek.dev", "FD"),
        ("Unified Dev", "UD"),
        ("akira-io/laravel-pdf", "AI"),
    ])
    func twoWords(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("takes two letters from a name that is one word", arguments: [
        ("unifieddev", "UN"),
        ("Unifieddev", "UN"),
        ("conductor", "CO"),
    ])
    func oneWord(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("skips a word that is only digits", arguments: [
        ("my-app-2", "MA"),
        ("app-2", "AP"),
        ("2-factor-auth", "FA"),
    ])
    func skipsNumbers(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("falls back to digits when the name has no letters at all", arguments: [
        ("2048", "20"),
        ("360", "36"),
        ("8", "8"),
    ])
    func digitsOnly(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("treats a camel hump as a word break", arguments: [
        ("MyApp", "MA"),
        ("UnifiedDevCore", "UD"),
        ("iOSClient", "IO"),
    ])
    func camelCase(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("does not break inside a run of capitals")
    func acronym() {
        #expect(RepoMonogram.initials(for: "HTTPServer") == "HT")
    }

    @Test("keeps a leading emoji as the whole monogram", arguments: [
        ("🌸 garden", "🌸"),
        ("🚀", "🚀"),
        ("🇧🇪-site", "🇧🇪"),
        ("❤️-notes", "❤️"),
    ])
    func leadingEmoji(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("ignores an emoji that is not first")
    func trailingEmoji() {
        #expect(RepoMonogram.initials(for: "unifieddev 🌸") == "UN")
    }

    @Test("uppercases without widening the monogram")
    func sharpS() {
        #expect(RepoMonogram.initials(for: "ßeta-release").count == 2)
        #expect(RepoMonogram.initials(for: "ßeta") == "SE")
    }

    @Test("keeps letters outside ASCII", arguments: [
        ("ærø-tools", "ÆT"),
        ("Ünster", "ÜN"),
        ("日本語", "日本"),
    ])
    func unicodeLetters(name: String, initials: String) {
        #expect(RepoMonogram.initials(for: name) == initials)
    }

    @Test("gives nothing back when there is nothing to take", arguments: ["", "   ", "---", "//"])
    func nothingToTake(name: String) {
        #expect(RepoMonogram.initials(for: name).isEmpty)
    }

    @Test("never returns more than two characters", arguments: [
        "there-there", "unifieddev", "a-very-long-project-name-indeed", "2048", "ærø", "ßeta",
    ])
    func neverWiderThanTwo(name: String) {
        #expect(RepoMonogram.initials(for: name).count <= 2)
    }
}

@Suite("Emoji marks in a project name")
struct RepoMarkTests {
    @Test("reads the leading emoji as the mark", arguments: [
        ("🌸 Garden", "🌸"),
        ("🌸Garden", "🌸"),
        ("🌸", "🌸"),
    ])
    func readsLeadingEmoji(name: String, expected: String) {
        #expect(RepoMonogram.mark(in: name) == expected)
    }

    @Test("finds no mark where the name has none", arguments: [
        "unifieddev 🌸", "there-there", "2048", "", "   ",
    ])
    func findsNoMark(name: String) {
        #expect(RepoMonogram.mark(in: name).isEmpty)
    }

    @Test("takes the emoji off and tidies the space behind it")
    func stripsTheMark() {
        #expect(RepoMonogram.nameWithoutMark("🌸 Garden") == "Garden")
        #expect(RepoMonogram.nameWithoutMark("🌸Garden") == "Garden")
    }

    @Test("leaves a name that carries no mark exactly as it is")
    func leavesUnmarkedNames() {
        #expect(RepoMonogram.nameWithoutMark("Garden") == "Garden")
        #expect(RepoMonogram.nameWithoutMark("unifieddev 🌸") == "unifieddev 🌸")
    }

    @Test("answers with nothing when the emoji was the whole name")
    func emojiOnlyNameStripsToNothing() {
        #expect(RepoMonogram.nameWithoutMark("🌸").isEmpty)
        #expect(RepoMonogram.nameWithoutMark("🌸   ").isEmpty)
    }
}
