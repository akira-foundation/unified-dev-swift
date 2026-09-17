import Testing
@testable import Core

@Suite("A crew call, as a reader meets it")
struct CrewPresentationTests {
    private func present(_ tool: String, _ input: [String: JSONValue] = [:]) -> ToolPresentation {
        ToolPresenter.present(
            name: "mcp__\(BridgeRegistration.serverName)__\(tool)", input: .object(input)
        )
    }

    @Test("starting one says so, and says who")
    func startingNamesTheAgent() {
        let row = present(CrewToolName.start, [
            "name": .string("read-the-cascade"),
            "task": .string("Read every file under Sources/Core/Git and report."),
        ])

        #expect(row.label == "Start subagent")
        #expect(row.detail == "read-the-cascade")
    }

    @Test("saying something names the agent it was said to, not what was said")
    func sayingNamesTheTarget() {
        let row = present(CrewToolName.say, [
            "to": .string("tests"),
            "message": .string("The parser moved to Sources/Core/Git/DiffParser.swift."),
        ])

        #expect(row.label == "Say to")
        #expect(row.detail == "tests")
    }

    @Test("a subagent talking upwards names nobody")
    func sayingUpwardsNamesNobody() {
        let row = present(CrewToolName.say, ["message": .string("I am done with the read.")])

        #expect(row.label == "Say to")
        #expect(row.detail.isEmpty)
    }

    @Test("listing takes no arguments and draws none")
    func listingIsTheLabelAlone() {
        let row = present(CrewToolName.list)

        #expect(row.label == "List subagents")
        #expect(row.detail.isEmpty)
    }

    @Test("a listing that carries a count shows it, as prose")
    func listingShowsACount() {
        let row = present(CrewToolName.list, ["count": .integer(3)])

        #expect(row.detail == "3")
        #expect(!row.detailIsCode)
    }

    @Test("stopping one says so, and says which")
    func stoppingNamesTheAgent() {
        let row = present(CrewToolName.stop, ["name": .string("tests")])

        #expect(row.label == "Stop subagent")
        #expect(row.detail == "tests")
    }

    @Test("none of them names the transport or the puzzle piece")
    func noneOfThemNamesTheTransport() {
        for tool in [CrewToolName.start, CrewToolName.say, CrewToolName.list, CrewToolName.stop] {
            let row = present(tool, ["name": .string("tests"), "to": .string("tests")])
            #expect(!row.label.contains("bridge"), "\(tool) named the transport")
            #expect(!row.label.contains("Unified Dev:"), "\(tool) named the app rather than the act")
            #expect(row.glyph != "puzzlepiece.extension", "\(tool) drew the extension glyph")
        }
    }

    @Test("an agent's name is code, so it draws in mono")
    func aNameIsALiteral() {
        #expect(present(CrewToolName.start, ["name": .string("tests")]).literal == "tests")
        #expect(present(CrewToolName.say, ["to": .string("tests")]).literal == "tests")
        #expect(present(CrewToolName.stop, ["name": .string("tests")]).literal == "tests")

        for tool in [CrewToolName.start, CrewToolName.say, CrewToolName.stop] {
            #expect(present(tool, ["name": .string("tests"), "to": .string("tests")]).detailIsCode)
        }
    }

    @Test("a missing name is not an empty literal")
    func aMissingNameIsNoLiteral() {
        for tool in [CrewToolName.start, CrewToolName.say, CrewToolName.list, CrewToolName.stop] {
            let row = present(tool)
            #expect(row.literal == nil, "\(tool) claimed a literal it was never given")
            #expect(!row.detailIsCode)
        }
    }

    @Test("a name longer than a name is cut to one")
    func aRunawayNameIsCut() {
        let row = present(CrewToolName.start, ["name": .string(String(repeating: "a", count: 400))])

        #expect(row.detail.count <= Crew.nameLimit + 1)
        #expect(row.detail.hasSuffix("\u{2026}"))
    }

    @Test("a name with a newline in it is still one line")
    func aNameStaysOnOneLine() {
        let row = present(CrewToolName.stop, ["name": .string("tests\nand docs")])

        #expect(row.detail == "tests and docs")
    }

    @Test("another bridge tool keeps the row it had")
    func anotherBridgeToolIsUnchanged() {
        let row = present("pane_open")

        #expect(row.label == "Unified Dev: pane open")
        #expect(row.literal == nil)
    }

    @Test("a file naming tool still finds its file")
    func aFileIsStillFound() {
        let row = ToolPresenter.present(
            name: "mcp__linear__attach", input: .object(["path": .string("/tmp/notes.md")])
        )

        #expect(row.literal == "/tmp/notes.md")
        #expect(row.chips == [.file(path: "/tmp/notes.md")])
    }
}
