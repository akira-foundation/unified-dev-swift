import Testing
import Foundation
@testable import Core

@Suite("Output styles", .scratchDirectory)
struct OutputStyleTests {
    struct Tree {
        let home: String
        let project: String

        init() throws {
            home = TestScratch.unique("home")
            project = TestScratch.unique("project")
            try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: project, withIntermediateDirectories: true)
        }

        func write(_ relative: String, _ contents: String, under root: String? = nil) throws {
            let path = ((root ?? home) as NSString).appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            try contents.write(toFile: path, atomically: true, encoding: .utf8)
        }

        func discover() -> [OutputStyle] {
            OutputStyleIndex.discover(home: home, project: project)
        }

        func names() -> [String] {
            discover().map(\.name)
        }
    }

    @Test("the built in styles are the ones the CLI carries, in its own order")
    func builtIns() {
        #expect(OutputStyle.builtIns.map(\.name) == [
            "default", "Proactive", "Concise", "Explanatory", "Learning",
        ])
        #expect(OutputStyle.builtIns.allSatisfy { $0.isBuiltIn })
        #expect(OutputStyle.builtIns.allSatisfy { !$0.detail.isEmpty })
    }

    @Test("Concise describes itself the way the binary does")
    func conciseDetail() throws {
        let concise = try #require(OutputStyle.builtIns.first { $0.name == "Concise" })

        #expect(
            concise.detail
                == "Claude responds tersely, leading with results and skipping preamble and narration"
        )
    }

    @Test("a machine with no style directories at all still gets the built in list")
    func noDirectories() throws {
        let tree = try Tree()

        #expect(tree.names() == OutputStyle.builtIns.map(\.name))
    }

    @Test("a style in the home directory joins the list")
    func userStyle() throws {
        let tree = try Tree()
        try tree.write(
            ".claude/output-styles/blunt.md",
            "---\nname: Blunt\ndescription: Claude says the thing and stops\n---\n\nBe blunt.\n"
        )

        let found = try #require(tree.discover().first { $0.name == "Blunt" })
        #expect(found.detail == "Claude says the thing and stops")
        #expect(!found.isBuiltIn)
    }

    @Test("a style in the checkout joins the list too")
    func projectStyle() throws {
        let tree = try Tree()
        try tree.write(
            ".claude/output-styles/house.md",
            "---\ndescription: The house voice\n---\n\nWrite like the handbook.\n",
            under: tree.project
        )

        #expect(tree.names().contains("house"))
    }

    @Test("a style with no frontmatter is named by its file")
    func nameFromFile() throws {
        let tree = try Tree()
        try tree.write(".claude/output-styles/terse.md", "Be terse.\n")

        let found = try #require(tree.discover().first { $0.name == "terse" })
        #expect(!found.detail.isEmpty)
    }

    @Test("a custom file cannot shadow a built in name")
    func builtInWins() throws {
        let tree = try Tree()
        try tree.write(
            ".claude/output-styles/Concise.md",
            "---\nname: Concise\ndescription: Something else entirely\n---\n\nNo.\n"
        )

        let concise = tree.discover().filter { $0.name == "Concise" }
        #expect(concise.count == 1)
        #expect(concise.first?.isBuiltIn == true)
    }

    @Test("the built in styles stay first and the found ones are sorted after them")
    func ordering() throws {
        let tree = try Tree()
        try tree.write(".claude/output-styles/zulu.md", "Z\n")
        try tree.write(".claude/output-styles/alpha.md", "A\n")

        #expect(tree.names() == [
            "default", "Proactive", "Concise", "Explanatory", "Learning", "alpha", "zulu",
        ])
    }

    @Test("a name that cannot be a menu row is left out", arguments: ["", "   ", "one\ntwo"])
    func rejectsUnusableNames(name: String) {
        #expect(OutputStyleIndex.sanitised(name) == nil)
    }

    @Test("a name with spaces and capitals is fine", arguments: ["Concise", "House Voice", "terse"])
    func acceptsOrdinaryNames(name: String) {
        #expect(OutputStyleIndex.sanitised(name) == name)
    }

    @Test("nothing chosen and the default chosen are the same thing")
    func defaultIsAbsence() {
        #expect(OutputStyle.isDefault(nil))
        #expect(OutputStyle.isDefault(""))
        #expect(OutputStyle.isDefault("  "))
        #expect(OutputStyle.isDefault("default"))
        #expect(!OutputStyle.isDefault("Concise"))
        #expect(!OutputStyle.isDefault("Default"))
    }
}
