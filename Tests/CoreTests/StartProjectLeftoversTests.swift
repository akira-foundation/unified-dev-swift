import Testing
@testable import Core

@Suite("What the start project card leaves behind")
struct StartProjectLeftoversTests {
    private let cloneFailed = CloneFailure(message: "Repository not found.", folderWasCreated: false)

    private let creationFailed = NewProjectFailure(
        title: "Could not start the project",
        message: "git init said no.",
        folderWasCreated: true
    )

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

    @Test("a clone in flight leaves the folder it was cloning into, and it goes whole")
    func cloneInFlight() {
        let behind = leftovers(.fetching)

        #expect(behind == StartProjectLeftovers(
            path: "/a/beacon", folderWasCreated: true, cloned: true
        ))
    }

    @Test("a clone that failed leaves the same folder, named by the half the fault came from")
    func cloneThatFailed() {
        let behind = leftovers(.after(cloneFailed))

        #expect(behind?.path == "/a/beacon")
        #expect(behind?.cloned == true)
    }

    @Test("the clone destination is never guessed from the typed name")
    func neverGuessesTheCloneDestination() {
        #expect(leftovers(.fetching, clonedInto: nil) == nil)
        #expect(leftovers(.fetching, clonedInto: "") == nil)
        #expect(leftovers(.after(cloneFailed), clonedInto: nil) == nil)
    }

    @Test("a project being created leaves the folder it was named after, not the clone destination")
    func projectInFlight() {
        let behind = leftovers(.creating(.initialise))

        #expect(behind == StartProjectLeftovers(
            path: "/a/harbour", folderWasCreated: true, cloned: false
        ))
    }

    @Test("a folder the app did not create is reported as not created, so it is kept")
    func keepsAFolderItDidNotMake() {
        let behind = leftovers(.creating(.commit), namedFolderWasCreated: false)

        #expect(behind?.folderWasCreated == false)
        #expect(behind?.cloned == false)
    }

    @Test("a creation that failed leaves the named folder")
    func creationThatFailed() {
        #expect(leftovers(.after(creationFailed))?.path == "/a/harbour")
        #expect(leftovers(.after(creationFailed))?.cloned == false)
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
}
