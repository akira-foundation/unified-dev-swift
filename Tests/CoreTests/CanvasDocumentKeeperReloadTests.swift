import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper reloads")
struct CanvasDocumentKeeperReloadTests {
    private let fixture = CanvasSessionFixture()

    private func opened() throws -> (keeper: CanvasDocumentKeeper, bytes: Data) {
        let bytes = try CanvasDocumentCodec.encode(fixture.session().document)
        return (CanvasDocumentKeeper(opening: .read(bytes)), bytes)
    }

    private func edit(_ keeper: inout CanvasDocumentKeeper) {
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
    }

    private func savedBytes(_ step: CanvasDiskStep?) -> Data? {
        if case .save(let data, _) = step { return data }
        return nil
    }

    private func held(_ keeper: CanvasDocumentKeeper) -> CanvasDocument? {
        if case .document(let document) = keeper.document { return document }
        return nil
    }

    private func outsideBytes() throws -> Data {
        var outside = fixture.session().document
        outside.elements.removeAll()
        return try CanvasDocumentCodec.encode(outside)
    }

    @Test func aReloadWritesTheCopyBeforeReplacingAndNamesIt() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let edited = try #require(held(keeper))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        let outside = try outsideBytes()
        keeper.finish(.read(outside))

        let step = keeper.nextStep()
        #expect(step == .backup(try CanvasDocumentCodec.encode(edited)))
        #expect(held(keeper) == edited)

        keeper.finish(.backedUp("/work/deck.udcanvas.backup-1"))

        #expect(held(keeper)?.elements.isEmpty == true)
        #expect(keeper.warning == .reloaded(backups: ["/work/deck.udcanvas.backup-1"], typingKeptIn: []))
        #expect(keeper.warning?.message.contains("deck.udcanvas.backup-1") == true)
        #expect(keeper.nextStep() == nil)
    }

    @Test func anEditDuringTheBackupGoesIntoAnotherCopyBeforeTheReplacement() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outsideBytes()))
        #expect(keeper.nextStep() != nil)
        edit(&keeper)
        let edited = try #require(held(keeper))

        keeper.finish(.backedUp("/work/first"))

        #expect(held(keeper) == edited)
        #expect(keeper.nextStep() == .backup(try CanvasDocumentCodec.encode(edited)))
        keeper.finish(.backedUp("/work/second"))
        #expect(held(keeper)?.elements.isEmpty == true)
        #expect(keeper.warning == .reloaded(backups: ["/work/first", "/work/second"], typingKeptIn: []))
    }

    @Test func aBackupThatCannotBeWrittenRefusesTheReplacement() throws {
        var (keeper, _) = try opened()
        let original = held(keeper)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outsideBytes()))
        #expect(keeper.nextStep() != nil)

        keeper.finish(.backupFailed("disk full"))

        #expect(held(keeper) == original)
        #expect(keeper.warning == .backupFailed("disk full"))
        #expect(keeper.reloads == 0)
        edit(&keeper)
        #expect(keeper.nextStep() == nil)
    }

    @Test func formattingOnlyReloadsWithoutACopyOrAWarning() throws {
        var (keeper, _) = try opened()
        let original = held(keeper)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let compact = try encoder.encode(fixture.session().document)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)

        keeper.finish(.read(compact))

        #expect(keeper.nextStep() == nil)
        #expect(keeper.warning == nil)
        #expect(keeper.reloads == 1)
        #expect(held(keeper)?.elements.map(\.rect) == original?.elements.map(\.rect))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(compact))
        #expect(keeper.reloads == 1)
    }

    @Test func aCorruptFileStopsSavingKeepsTheDocumentAndOffersBothWays() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let edited = held(keeper)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)

        keeper.finish(.read(Data("{ not json".utf8)))

        #expect(held(keeper) == edited)
        #expect(keeper.nextStep() == nil)
        #expect(keeper.warning?.actions == [.saveOver, .reload])
        edit(&keeper)
        #expect(keeper.nextStep() == nil)
    }

    @Test func savingOverACorruptFileIsDeliberateAndUnchecked() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(Data("{ not json".utf8)))

        keeper.perform(.saveOver)
        let step = keeper.nextStep()

        guard case .save(let data, expecting: nil) = step else {
            Issue.record("expected an unchecked save, got \(String(describing: step))")
            return
        }
        #expect(keeper.warning == nil)
        keeper.finish(.written(data))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(data))
        #expect(keeper.warning == nil)
    }

    @Test func aReadInFlightCannotBlockADeliberateSave() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(Data("{ not json".utf8)))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.perform(.saveOver)

        keeper.finish(.read(Data("{ not json".utf8)))

        #expect(keeper.warning == nil)
        guard case .save(_, expecting: nil) = keeper.nextStep() else {
            Issue.record("the deliberate save did not go ahead")
            return
        }
    }

    @Test func aFileThatComesBackAsWeWroteItResumesSaving() throws {
        var (keeper, bytes) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(nil))
        edit(&keeper)
        #expect(keeper.nextStep() == nil)
        #expect(keeper.warning == .vanished)

        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(bytes))

        #expect(keeper.warning == nil)
        #expect(savedBytes(keeper.nextStep()) != nil)
    }

    @Test func aVanishedFileStopsSavingUntilTheOwnerSavesAgain() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let edited = try #require(held(keeper))
        #expect(keeper.nextStep() != nil)

        keeper.finish(.outsideChange)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(nil))

        #expect(keeper.warning == .vanished)
        #expect(keeper.warning?.actions == [.saveAgain])
        #expect(keeper.nextStep() == nil)
        #expect(held(keeper) == edited)

        keeper.perform(.saveAgain)
        guard case .save(let data, expecting: nil) = keeper.nextStep() else {
            Issue.record("save again did not write")
            return
        }
        #expect(data == (try CanvasDocumentCodec.encode(edited)))
    }

    @Test func saveAgainWritesEvenWhenTheBytesAreWhatWasLastWritten() throws {
        var (keeper, bytes) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(nil))

        keeper.perform(.saveAgain)

        #expect(keeper.nextStep() == .save(bytes, expecting: nil))
    }

    @Test func anUnreadableFileAtOpenBecomesADocumentOnceItCanBeRead() throws {
        let bytes = try CanvasDocumentCodec.encode(fixture.session().document)
        var keeper = CanvasDocumentKeeper(opening: .read(Data("{ not json".utf8)))
        guard case .corrupt = keeper.document else {
            Issue.record("expected corrupt, got \(keeper.document)")
            return
        }
        #expect(keeper.apply([], by: .owner) == nil)

        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(bytes))

        #expect(held(keeper) == fixture.session().document)
        #expect(keeper.warning == nil)
        #expect(keeper.nextStep() == nil)
    }

    @Test func aFileThatCannotBeReadPausesSavingRatherThanCountingAsGone() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)

        keeper.finish(.unreadable("permission denied"))

        guard case .refused(let reason) = keeper.warning else {
            Issue.record("expected a refusal, got \(String(describing: keeper.warning))")
            return
        }
        #expect(reason.contains("permission denied"))
    }

    @Test func undoAndRedoAreSaved() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let first = try #require(savedBytes(keeper.nextStep()))
        keeper.finish(.written(first))

        let undone = keeper.undo()
        #expect(undone)
        let afterUndo = try #require(savedBytes(keeper.nextStep()))
        keeper.finish(.written(afterUndo))
        let redone = keeper.redo()
        #expect(redone)

        #expect(savedBytes(keeper.nextStep()) != nil)
    }

    @Test func aStaleAgentRevisionConflictsAfterUndo() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let undone = keeper.undo()
        #expect(undone)

        let stale = keeper.apply([fixture.move(fixture.boxID, revision: 0)], by: .agent)

        guard case .conflict = stale else {
            Issue.record("the agent's revision from before the undo went through: \(String(describing: stale))")
            return
        }
    }

    @Test func dismissingRemovesTheNotice() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outsideBytes()))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/copy"))
        #expect(keeper.warning?.actions == [.dismiss])

        keeper.perform(.dismiss)

        #expect(keeper.warning == nil)
    }
}
