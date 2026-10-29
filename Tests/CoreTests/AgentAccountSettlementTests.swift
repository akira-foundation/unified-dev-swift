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

    @Test func anEmptyDirectoryMadeByTheCreationIsRemovedWhenNothingSettles() throws {
        let made = plan(support: scratchSupport())
        try AgentAccountCreation.prepareDirectory(of: made.home)

        let removed = made.discardUnusedDirectory(existedBefore: false)

        #expect(removed)
        #expect(!made.directoryExists)
    }

    @Test func aDirectoryThatExistedBeforeTheCreationIsNeverRemoved() throws {
        let made = plan(support: scratchSupport())
        try AgentAccountCreation.prepareDirectory(of: made.home)

        let removed = made.discardUnusedDirectory(existedBefore: true)

        #expect(!removed)
        #expect(made.directoryExists)
    }

    @Test func aDirectoryWithAnythingInsideIsNeverRemoved() throws {
        let made = plan(support: scratchSupport())
        try writeIdentity(of: made)

        let removed = made.discardUnusedDirectory(existedBefore: false)

        #expect(!removed)
        #expect(made.directoryExists)
    }

    @Test func discardingADirectoryThatIsNotThereIsHarmless() {
        let made = plan(support: scratchSupport())

        #expect(!made.discardUnusedDirectory(existedBefore: false))
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
