import Testing
import Foundation
@testable import Core

@Suite("File mention")
struct FileMentionTests {
    @Test("a path names a file", arguments: [
        ".unifieddev/scratch/pr-instructions.md",
        ".unifieddev/pr-instructions.md",
        "Sources/UnifiedDev/Views/Transcript/UserTurnRowView.swift",
        "app/Http/Controllers/BeaconController.php",
        "/Users/freek/dev/code/unifieddev/Package.swift",
        "./Tools/house-rules.sh",
        "config/lights.tpl",
    ])
    func acceptsPaths(span: String) {
        #expect(FileMention.names(span))
    }

    @Test("a bare name with a known extension names a file", arguments: [
        "foo.md",
        "README.md",
        "Package.swift",
        "composer.json",
        "docker-compose.yml",
        "icon@2x.png",
        "Package.resolved",
        "layout_v2.blade.php",
    ])
    func acceptsBareNames(span: String) {
        #expect(FileMention.names(span))
    }

    @Test("a dotted identifier is not a file", arguments: [
        "NSApp.activate",
        "store.state",
        "Duration.seconds",
        "self.workspace",
        "console.log",
        "array.map",
        "response.data",
        "process.env",
        "model.app",
    ])
    func rejectsIdentifiers(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("a command is not a file", arguments: [
        "git status",
        "make build",
        "swift build -c release",
        "gh pr merge",
    ])
    func rejectsCommands(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("a flag, a branch and a bare word are not files", arguments: [
        "--force",
        "-f",
        "main",
        "origin/main",
        "HEAD",
        "feature/user-bubble",
    ])
    func rejectsWords(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("an address is not a file", arguments: [
        "https://github.com/akira-io/unifieddev",
        "http://localhost:3000/index.html",
        "github.com/akira-io/unifieddev",
    ])
    func rejectsAddresses(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("a glob is not a file", arguments: [
        "Sources/**/*.swift",
        "*.md",
        "{a,b}.swift",
    ])
    func rejectsGlobs(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("a version is not a file", arguments: ["1.2.3", "v0.3.0", "26.0"])
    func rejectsVersions(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("an unknown extension on a bare name is left as code", arguments: [
        "Makefile.custom",
        "notes.qqq",
    ])
    func rejectsUnknownExtensions(span: String) {
        #expect(!FileMention.names(span))
    }

    @Test("the turn Unified Dev sends to open a pull request draws its path as a file")
    func splitsThePullRequestTurn() {
        let text = PullRequestInstructions.asking(
            "Create a pull request for this workspace against main.",
            toFollow: PullRequestInstructions.scratchPath
        )

        #expect(FileMention.segments(in: text) == [
            .text("Create a pull request for this workspace against main.\n\nFollow the instructions in "),
            .attachment(".unifieddev/scratch/pr-instructions.md"),
            .text("."),
        ])
    }

    @Test("words either side of a file stay words")
    func keepsTheSentence() {
        let segments = FileMention.segments(in: "run `git status`, then read `notes.md` twice")

        #expect(segments == [
            .text("run `git status`, then read "),
            .attachment("notes.md"),
            .text(" twice"),
        ])
    }

    @Test("a turn with no files in it is one run of text")
    func leavesProseAlone() {
        let text = "Use `NSApp.activate` only behind a check, and never `--force`."
        #expect(FileMention.segments(in: text) == [.text(text)])
    }

    @Test("the segments put back together are the turn", arguments: [
        "Follow the instructions in `.unifieddev/scratch/pr-instructions.md`.",
        "`a.md` `b.md``c.md`",
        "an unclosed `backtick and `notes.md` after it",
        "```\nfenced\n```",
        "nothing backticked at all",
        "",
    ])
    func roundTrips(text: String) {
        #expect(FileMention.segments(in: text).map(\.text).joined() == text)
    }
}
