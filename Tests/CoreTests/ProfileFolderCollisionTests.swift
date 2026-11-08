import Foundation
import Testing
@testable import Core

@Suite("A profile folder and the directory of a project")
struct ProfileFolderCollisionTests {
    private let root = URL(fileURLWithPath: "/w", isDirectory: true)

    private func usable(
        _ folder: String,
        recorded: [String] = [],
        others: Set<String> = [],
        onDisk: Set<String> = []
    ) -> String {
        ProfileFolder.usable(
            folder, under: root, recordedWorktrees: recorded, otherProfiles: others,
            holdsWorktree: { onDisk.contains($0.lastPathComponent) }
        )
    }

    @Test func aFolderNothingOccupiesIsKept() {
        #expect(usable("unified") == "unified")
    }

    @Test func aWorktreeOfTheProfileItselfDoesNotMoveTheFolder() {
        #expect(usable("unified", recorded: ["/w/unified/billing/main"]) == "unified")
    }

    @Test func aProjectDirectoryOfTheSameNameMovesTheFolder() {
        #expect(usable("unified", recorded: ["/w/unified/old-branch"]) == "unified-2")
    }

    @Test func aProjectDirectoryThatDiffersOnlyInCaseMovesTheFolder() {
        #expect(usable("unified", recorded: ["/w/Unified/old-branch"]) == "unified-2")
    }

    @Test func aWorktreeOutsideTheRootDoesNotMoveTheFolder() {
        #expect(usable("unified", recorded: ["/elsewhere/unified/old-branch"]) == "unified")
    }

    @Test func aDirectoryFoundOnDiskMovesTheFolderWithNoRecord() {
        #expect(usable("unified", onDisk: ["unified"]) == "unified-2")
    }

    @Test func theNextNumberSkipsAnotherProjectDirectory() {
        #expect(usable("unified", recorded: ["/w/unified/a", "/w/unified-2/b"]) == "unified-3")
    }

    @Test func theNextNumberSkipsADirectoryFoundOnDisk() {
        #expect(usable("unified", onDisk: ["unified", "unified-2"]) == "unified-3")
    }

    @Test func theNextNumberSkipsADirectoryWithNoRecordAfterARecordedCollision() {
        #expect(usable("unified", recorded: ["/w/unified/a"], onDisk: ["unified-2"]) == "unified-3")
    }

    @Test func theNextNumberSkipsTheFolderOfAnotherProfile() {
        #expect(usable("unified", recorded: ["/w/unified/a"], others: ["unified-2"]) == "unified-3")
    }

    @Test func anotherProfileAloneDoesNotMoveTheFolder() {
        #expect(usable("unified", others: ["unified-2"]) == "unified")
    }

    @Test(.scratchDirectory) func aDirectoryThatCannotBeReadCountsAsHoldingOne() throws {
        let directory = URL(fileURLWithPath: TestScratch.unique("sealed"), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }

        #expect(ProfileFolder.containsWorktree(directory))
    }

    @Test(.scratchDirectory) func aDirectoryThatDoesNotExistHoldsNothing() {
        #expect(!ProfileFolder.containsWorktree(URL(fileURLWithPath: TestScratch.unique("absent"), isDirectory: true)))
    }

    @Test(.scratchDirectory) func aDirectoryHoldingACheckoutIsSeen() throws {
        let directory = URL(fileURLWithPath: TestScratch.unique("legacy"), isDirectory: true)
        let empty = directory.appendingPathComponent("branch", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        #expect(!ProfileFolder.containsWorktree(directory))

        try Data().write(to: empty.appendingPathComponent(".git"))

        #expect(ProfileFolder.containsWorktree(directory))
    }
}
