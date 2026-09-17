import Testing
import Foundation
@testable import Core

@Suite("Where an agent stands with no workspace", .scratchDirectory)
struct AgentScratchDirectoryTests {
    private func temporaryBase() -> String {
        let base = TestScratch.unique("agent-scratch")
        try? FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        return base
    }

    @Test("it is a folder of Unified Dev's own, beside whatever it was given")
    func pathIsInsideTheBase() {
        #expect(AgentScratchDirectory.path(in: "/somewhere") == "/somewhere/unifieddev-agent-scratch")
    }

    @Test("making it leaves a real directory behind")
    func makeCreatesIt() {
        let base = temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base) }

        let made = AgentScratchDirectory.make(in: base)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: made, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(made == AgentScratchDirectory.path(in: base))
    }

    @Test("there is nothing in it")
    func itIsEmpty() {
        let base = temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base) }

        let made = AgentScratchDirectory.make(in: base)

        let entries = (try? FileManager.default.contentsOfDirectory(atPath: made)) ?? ["unreadable"]
        #expect(entries.isEmpty)
    }

    @Test("asking twice is the same folder rather than a second one")
    func makeIsIdempotent() {
        let base = temporaryBase()
        defer { try? FileManager.default.removeItem(atPath: base) }

        #expect(AgentScratchDirectory.make(in: base) == AgentScratchDirectory.make(in: base))
        let siblings = (try? FileManager.default.contentsOfDirectory(atPath: base)) ?? []
        #expect(siblings == [AgentScratchDirectory.folderName])
    }

    @Test("a base it cannot write to falls back to the base, never to the home directory")
    func fallbackIsNotHome() {
        let made = AgentScratchDirectory.make(in: "/dev/null/nowhere")

        #expect(made != NSHomeDirectory())
        #expect(made == "/dev/null/nowhere")
    }

    @Test("the folder this Mac uses sits outside the home directory altogether")
    func liveFolderIsOutsideHome() {
        let live = AgentScratchDirectory.current()
        let home = NSHomeDirectory()

        #expect(live != home)
        #expect(!live.hasPrefix(home + "/"))
    }

    @Test("the namer stands in the same folder as everything else with no workspace")
    func namerSharesIt() {
        #expect(WorkspaceNamer.scratchDirectory == AgentScratchDirectory.current())
    }
}
