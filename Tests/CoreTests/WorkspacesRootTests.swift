import Testing
import Foundation
@testable import Core

@Suite("Where new worktrees are cut", .scratchDirectory)
struct WorkspacesRootTests {
    private func resolve(home: String, present: Set<String>) -> String {
        WorkspacesRoot.resolve(home: URL(fileURLWithPath: home)) {
            present.contains($0.path)
        }.path
    }

    @Test("a machine that has never run Unified Dev gets the folder Spotlight skips")
    func newInstallation() {
        #expect(resolve(home: "/Users/tester", present: []) == "/Users/tester/unifieddev/workspaces.noindex")
    }

    @Test("an installation that already has a root keeps it, whatever its name")
    func existingInstallationKeepsItsRoot() {
        let existing = resolve(home: "/Users/tester", present: ["/Users/tester/unifieddev/workspaces"])
        #expect(existing == "/Users/tester/unifieddev/workspaces")
    }

    @Test("an installation that has cut into the new folder stays in it")
    func newInstallationStaysPut() {
        let root = resolve(home: "/Users/tester", present: ["/Users/tester/unifieddev/workspaces.noindex"])
        #expect(root == "/Users/tester/unifieddev/workspaces.noindex")
    }

    @Test("a legacy folder appearing later does not steal an install already using the new one")
    func bothPresentPrefersTheNewOne() {
        let root = resolve(
            home: "/Users/tester",
            present: ["/Users/tester/unifieddev/workspaces", "/Users/tester/unifieddev/workspaces.noindex"]
        )
        #expect(root == "/Users/tester/unifieddev/workspaces.noindex")
    }

    @Test("making the folder by hand is how an existing install opts in")
    func optingInByHand() throws {
        let home = TestScratch.unique("home-optin")
        let noindex = (home as NSString).appendingPathComponent("unifieddev/workspaces.noindex")
        let legacy = (home as NSString).appendingPathComponent("unifieddev/workspaces")
        for path in [legacy, noindex] {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        let root = WorkspacesRoot.resolve(home: URL(fileURLWithPath: home))
        #expect(root.path == noindex)
    }

    @Test("asks a real disk, and reads an existing folder off it")
    func readsARealDisk() throws {
        let home = TestScratch.unique("home-existing")
        let legacy = (home as NSString).appendingPathComponent("unifieddev/workspaces")
        try FileManager.default.createDirectory(atPath: legacy, withIntermediateDirectories: true)

        let root = WorkspacesRoot.resolve(home: URL(fileURLWithPath: home))
        #expect(root.path == legacy)
    }

    @Test("a real disk with nothing on it gets the folder Spotlight skips")
    func readsARealDiskWithNoRoot() throws {
        let home = TestScratch.unique("home-empty")
        try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)

        let root = WorkspacesRoot.resolve(home: URL(fileURLWithPath: home))
        let expected = (home as NSString).appendingPathComponent("unifieddev/workspaces.noindex")
        #expect(root.path == expected)
    }

    @Test("a file named workspaces is not a workspaces root")
    func aFileIsNotARoot() throws {
        let home = TestScratch.unique("home-file")
        let unifieddev = (home as NSString).appendingPathComponent("unifieddev")
        try FileManager.default.createDirectory(atPath: unifieddev, withIntermediateDirectories: true)
        let file = (unifieddev as NSString).appendingPathComponent("workspaces")
        try "not a folder".write(toFile: file, atomically: true, encoding: .utf8)

        let root = WorkspacesRoot.resolve(home: URL(fileURLWithPath: home))
        let expected = (home as NSString).appendingPathComponent("unifieddev/workspaces.noindex")
        #expect(root.path == expected)
    }

    @Test("the folder a new installation gets is named for the suffix that does the work")
    func theNameIsTheMechanism() {
        #expect(WorkspacesRoot.preferredName.hasSuffix(".noindex"))
        #expect(!WorkspacesRoot.legacyName.hasSuffix(".noindex"))
    }

    @Test("the settings row says something different to each kind of installation")
    func theNoteExplainsWhichRootThisIs() {
        let new = WorkspacesRoot.note(for: URL(fileURLWithPath: "/Users/tester/unifieddev/workspaces.noindex"))
        let old = WorkspacesRoot.note(for: URL(fileURLWithPath: "/Users/tester/unifieddev/workspaces"))
        #expect(new != old)
        #expect(old.contains("keeps the folder it already has"))
        #expect(new.contains(".noindex"))
    }

    @Test("WorkspaceManager reads the rule rather than repeating it")
    func theManagerUsesTheRule() {
        #expect(WorkspaceManager.workspacesRoot == WorkspacesRoot.resolve())
    }
}
