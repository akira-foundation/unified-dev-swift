import Foundation
import Testing
@testable import Core

@Suite("What the start project card leaves behind")
struct StartProjectLeftoversTests {
    private func cloneFailed(folderWasCreated: Bool) -> CloneFailure {
        CloneFailure(message: "Repository not found.", folderWasCreated: folderWasCreated)
    }

    private func creationFailed(folderWasCreated: Bool) -> NewProjectFailure {
        NewProjectFailure(
            title: "Could not start the project",
            message: "git init said no.",
            folderWasCreated: folderWasCreated
        )
    }

    private func leftovers(
        _ stage: StartProjectStage,
        namedFolder: String = "/a/harbour",
        namedFolderWasCreated: Bool = true,
        clonedInto: String? = "/a/beacon"
    ) -> StartProjectLeftovers? {
        StartProjectLeftovers.of(
            stage,
            namedFolder: namedFolder,
            namedFolderWasCreated: namedFolderWasCreated,
            clonedInto: clonedInto
        )
    }

    @Test("a clone in flight leaves the folder it claimed, and it goes whole")
    func cloneInFlight() {
        #expect(leftovers(.fetching) == StartProjectLeftovers(
            path: "/a/beacon", folderWasCreated: true, cloned: true
        ))
    }

    @Test("the clone destination is never guessed from the typed name")
    func neverGuessesTheCloneDestination() {
        #expect(leftovers(.fetching, clonedInto: nil) == nil)
        #expect(leftovers(.fetching, clonedInto: "") == nil)
        #expect(leftovers(.after(cloneFailed(folderWasCreated: true)), clonedInto: nil) == nil)
    }

    @Test("a clone whose own cleanup already ran leaves nothing, so Close cannot delete a reclone")
    func cloneThatCleanedUpAfterItself() {
        #expect(leftovers(.after(cloneFailed(folderWasCreated: false))) == nil)
    }

    @Test("a clone failure that did leave a folder reports it, and reports it as a clone")
    func cloneThatLeftSomething() {
        let behind = leftovers(.after(cloneFailed(folderWasCreated: true)))

        #expect(behind?.path == "/a/beacon")
        #expect(behind?.cloned == true)
        #expect(behind?.folderWasCreated == true)
    }

    @Test("a project being created leaves the folder it was named after, not the clone destination")
    func projectInFlight() {
        #expect(leftovers(.creating(.initialise)) == StartProjectLeftovers(
            path: "/a/harbour", folderWasCreated: true, cloned: false
        ))
    }

    @Test("a folder the app did not create is reported as not created, so it is kept")
    func keepsAFolderItDidNotMake() {
        let behind = leftovers(.creating(.commit), namedFolderWasCreated: false)

        #expect(behind?.folderWasCreated == false)
        #expect(behind?.cloned == false)
    }

    @Test("a creation failure carries its own answer about the folder, not the one from before")
    func creationThatFailed() {
        #expect(leftovers(.after(creationFailed(folderWasCreated: true)))?.path == "/a/harbour")
        #expect(leftovers(
            .after(creationFailed(folderWasCreated: false)), namedFolderWasCreated: true
        )?.folderWasCreated == false)
    }

    @Test("nothing is left behind from a stage where no work ran")
    func nothingFromAnIdleStage() {
        #expect(leftovers(.landing) == nil)
        #expect(leftovers(.naming) == nil)
        #expect(leftovers(.cloning) == nil)
    }

    @Test("an empty named folder leaves nothing, so no removal is attempted at the root")
    func emptyNamedFolderLeavesNothing() {
        #expect(leftovers(.creating(.initialise), namedFolder: "") == nil)
    }

    @Test("discarding a clone it claimed removes the folder", .tags(.git, .subprocess))
    func discardRemovesAClaimedClone() async throws {
        let folder = TestScratch.unique("unifieddev-clone")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let behind = StartProjectLeftovers(path: folder, folderWasCreated: true, cloned: true)

        await behind.discard()

        #expect(!FolderPath.exists(folder))
    }

    @Test("discarding leaves a clone destination it did not claim", .tags(.git, .subprocess))
    func discardKeepsAnUnclaimedClone() async throws {
        let folder = TestScratch.unique("unifieddev-clone")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let behind = StartProjectLeftovers(path: folder, folderWasCreated: false, cloned: true)

        await behind.discard()

        #expect(FolderPath.exists(folder))
    }

    @Test("a named folder is still reported when the app did not create it, so the stray git goes")
    func reportsANamedFolderItDidNotCreate() {
        let behind = leftovers(.creating(.commit), namedFolderWasCreated: false)

        #expect(behind?.path == "/a/harbour")
        #expect(behind?.folderWasCreated == false)
    }

    @Test("discarding a named folder goes through the project starter, which keeps what has work in it", .tags(.git, .subprocess))
    func discardKeepsANamedFolderWithWorkInIt() async throws {
        let folder = TestScratch.unique("unifieddev-project")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try "keep me\n".write(
            toFile: (folder as NSString).appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )
        let behind = StartProjectLeftovers(path: folder, folderWasCreated: true, cloned: false)

        await behind.discard()

        #expect(FolderPath.exists(folder))
    }
}
