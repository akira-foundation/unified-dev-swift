import Testing
import Foundation
import Synchronization
@testable import Core

@Suite("Agent account settlement")
struct AgentAccountSettlementTests {
    private func scratchSupport() -> URL {
        URL(filePath: TestScratch.unique("support"), directoryHint: .isDirectory)
    }

    private func plan(support: URL, label: String = "Client") -> AgentAccountCreation {
        AgentAccountCreation.plan(provider: .claudeCode, label: label, existing: [], support: support)
    }

    private func writeIdentity(of plan: AgentAccountCreation) throws {
        try AgentAccountCreation.prepareDirectory(of: plan.home)
        try Data(#"{"oauthAccount":{"emailAddress":"a@b.c"}}"#.utf8).write(to: plan.home.identityPath)
    }

    @Test func aLoginThatExitedCleanlyAsksTheCliAndSettlesOnItsAnswer() async throws {
        let support = scratchSupport()
        let made = plan(support: support)
        try writeIdentity(of: made)

        let standing = await AgentAccountInventory.concluding(made, exit: .exited(0), defaults: []) { _ in .claimsSession }

        #expect(standing?.identity.email == "a@b.c")
        #expect(standing?.cliReport == .claimsSession)
    }

    @Test func aCleanExitTheCliDisownsSettlesToNothing() async throws {
        let support = scratchSupport()
        let made = plan(support: support)
        try writeIdentity(of: made)

        let standing = await AgentAccountInventory.concluding(made, exit: .exited(0), defaults: []) { _ in .claimsNoSession }

        #expect(standing == nil)
    }

    @Test(arguments: [TerminalExit?.none, .exited(1), .exited(130), .killed(15), .unknown])
    func aLoginThatDidNotExitCleanlyNeverAsksTheCliAndSettlesToNothing(exit: TerminalExit?) async throws {
        let support = scratchSupport()
        let made = plan(support: support)
        try writeIdentity(of: made)
        let asked = Mutex(0)

        let standing = await AgentAccountInventory.concluding(made, exit: exit, defaults: []) { _ in
            asked.withLock { $0 += 1 }
            return .claimsSession
        }

        #expect(standing == nil)
        #expect(asked.withLock { $0 } == 0)
    }

    @Test func aLoginTheCliDidNotAnswerForSettlesOnlyWhenItLeftAnIdentity() async throws {
        let support = scratchSupport()
        let empty = plan(support: support, label: "Empty")
        try AgentAccountCreation.prepareDirectory(of: empty.home)
        let written = plan(support: support, label: "Written")
        try writeIdentity(of: written)

        let nothing = await AgentAccountInventory.concluding(empty, exit: .exited(0), defaults: []) { _ in .unanswered }
        let something = await AgentAccountInventory.concluding(written, exit: .exited(0), defaults: []) { _ in .unanswered }

        #expect(nothing == nil)
        #expect(something?.cliReport == .unanswered)
    }

    @Test func aReservedDirectoryIsRemovedWhenNothingSettles() throws {
        let made = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: scratchSupport()
        )

        #expect(made.directoryExists)
        #expect(made.discardReservedDirectory())
        #expect(!made.directoryExists)
    }

    @Test func aReservedDirectoryIsRemovedEvenWithTheInterruptedLoginsFileInside() throws {
        let made = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: scratchSupport()
        )
        try Data(#"{"oauthAccount":{"emailAddress":"a@b.c"}}"#.utf8).write(to: made.home.identityPath)

        #expect(made.discardReservedDirectory())
        #expect(!made.directoryExists)
    }

    @Test func discardingADirectoryThatIsNotThereIsHarmless() {
        let made = plan(support: scratchSupport())

        #expect(!made.discardReservedDirectory())
    }

    @Test func twoCreationsOfTheSameLabelBeforeEitherSignsInGetDifferentFolders() throws {
        let support = scratchSupport()

        let first = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support)
        let second = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support)

        #expect(first.directory != second.directory)
        #expect(first.directoryExists && second.directoryExists)
    }

    @Test func theCreationThatFailsNeverTouchesTheFolderOfTheOneThatSucceeded() throws {
        let support = scratchSupport()
        let succeeded = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support)
        try writeIdentity(of: succeeded)
        let failed = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support)

        failed.discardReservedDirectory()

        #expect(succeeded.directoryExists)
        #expect(FileManager.default.fileExists(atPath: succeeded.home.identityPath.path))
    }

    @Test func aReservationAvoidsTheIdentifiersOfRowsAndOfFoldersOnDisk() throws {
        let support = scratchSupport()
        let held = try AgentAccountCreation.reserve(provider: .codex, label: "Lab", existing: [], support: support)

        let made = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Lab", existing: [AgentAccountID("lab-2")], support: support
        )

        #expect(made.id != held.id)
        #expect(made.id != AgentAccountID("lab-2"))
    }

    @Test func aLabelIsTrimmedAndAnEmptyOneIsRefused() {
        #expect(AgentAccountCreation.cleanLabel("  Client work \n") == "Client work")
        #expect(AgentAccountCreation.cleanLabel(" \n\t ") == nil)
        #expect(AgentAccountCreation.cleanLabel("") == nil)
    }

    @Test func aLongLabelIsCutToTheLimit() {
        let cut = AgentAccountCreation.cleanLabel(String(repeating: "x", count: 500))
        #expect(cut?.count == AgentAccountCreation.maxLabelLength)
    }

    @Test func theDirectoriesOnDiskAreOccupiedIdentifiersOfEveryProvider() throws {
        let support = scratchSupport()
        let claude = plan(support: support, label: "Client")
        let codex = AgentAccountCreation.plan(provider: .codex, label: "Lab", existing: [], support: support)
        try AgentAccountCreation.prepareDirectory(of: claude.home)
        try AgentAccountCreation.prepareDirectory(of: codex.home)

        let occupied = AgentAccountCreation.occupiedIDs(support: support)

        #expect(Set(occupied) == [claude.id, codex.id])
    }

    @Test func aLeftoverDirectoryIsNotReusedByTheNextCreationWithTheSameLabel() throws {
        let support = scratchSupport()
        let first = plan(support: support)
        try writeIdentity(of: first)

        let second = AgentAccountCreation.plan(
            provider: .claudeCode, label: "Client",
            existing: AgentAccountCreation.occupiedIDs(support: support), support: support
        )

        #expect(second.id != first.id)
        #expect(second.directory != first.directory)
    }

    @Test func withoutAnAccountsRootNothingIsOccupied() {
        #expect(AgentAccountCreation.occupiedIDs(support: scratchSupport()).isEmpty)
    }
}
