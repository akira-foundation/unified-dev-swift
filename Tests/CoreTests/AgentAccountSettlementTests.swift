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
        AgentAccountCreation.plan(
            provider: .claudeCode, label: label, existing: [], support: support, discriminant: "fixed"
        )
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

        #expect(made.plan.directoryExists)
        #expect(made.discard())
        #expect(!made.plan.directoryExists)
    }

    @Test func aReservedDirectoryIsRemovedEvenWithTheInterruptedLoginsFileInside() throws {
        let made = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: scratchSupport()
        )
        try Data(#"{"oauthAccount":{"emailAddress":"a@b.c"}}"#.utf8).write(to: made.plan.home.identityPath)

        #expect(made.discard())
        #expect(!made.plan.directoryExists)
    }

    @Test func discardingAReservationWhoseDirectoryIsGoneIsHarmless() throws {
        let made = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Client", existing: [], support: scratchSupport()
        )
        made.discard()

        #expect(!made.discard())
    }

    @Test func twoCreationsOfTheSameLabelBeforeEitherSignsInGetDifferentFolders() throws {
        let support = scratchSupport()

        let first = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support, discriminant: "fixed")
        let second = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support, discriminant: "fixed")

        #expect(first.plan.directory != second.plan.directory)
        #expect(first.plan.directoryExists && second.plan.directoryExists)
    }

    @Test func theCreationThatFailsNeverTouchesTheFolderOfTheOneThatSucceeded() throws {
        let support = scratchSupport()
        let succeeded = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support, discriminant: "fixed")
        try writeIdentity(of: succeeded.plan)
        let failed = try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support, discriminant: "fixed")

        failed.discard()

        #expect(succeeded.plan.directoryExists)
        #expect(FileManager.default.fileExists(atPath: succeeded.plan.home.identityPath.path))
    }

    @Test func aReservationAvoidsTheIdentifiersOfRowsAndOfFoldersOnDisk() throws {
        let support = scratchSupport()
        let held = try AgentAccountCreation.reserve(provider: .codex, label: "Lab", existing: [], support: support, discriminant: "fixed")

        let made = try AgentAccountCreation.reserve(
            provider: .claudeCode, label: "Lab", existing: [AgentAccountID("lab-fixed-2")], support: support,
            discriminant: "fixed"
        )

        #expect(held.plan.id == AgentAccountID("lab-fixed"))
        #expect(made.plan.id == AgentAccountID("lab-fixed-3"))
    }

    @Test func aReservationRefusesAFolderThatIsAlreadyThereEvenWhenTheListingCannotSeeIt() throws {
        let support = scratchSupport()
        let target = plan(support: support)
        let transcript = target.directory.appending(path: "transcript.jsonl")
        try FileManager.default.createDirectory(at: target.directory, withIntermediateDirectories: true)
        try Data("session".utf8).write(to: transcript)
        let providerFolder = target.directory.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o300], ofItemAtPath: providerFolder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: providerFolder.path) }

        #expect(AgentAccountCreation.occupiedIDs(support: support).isEmpty)
        #expect(throws: AgentAccountError.folderAlreadyThere(target.directory.path)) {
            try AgentAccountCreation.reserve(provider: .claudeCode, label: "Client", existing: [], support: support, discriminant: "fixed")
        }

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: providerFolder.path)
        #expect(FileManager.default.fileExists(atPath: transcript.path))
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
        let codex = AgentAccountCreation.plan(provider: .codex, label: "Lab", existing: [], support: support, discriminant: "fixed")
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
            existing: AgentAccountCreation.occupiedIDs(support: support), support: support, discriminant: "fixed"
        )

        #expect(second.id != first.id)
        #expect(second.directory != first.directory)
    }

    @Test func withoutAnAccountsRootNothingIsOccupied() {
        #expect(AgentAccountCreation.occupiedIDs(support: scratchSupport()).isEmpty)
    }
}
