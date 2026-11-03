import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper copies and revisions")
struct CanvasDocumentKeeperCopiesTests {
    private let fixture = CanvasSessionFixture()

    private func opened() throws -> (keeper: CanvasDocumentKeeper, bytes: Data) {
        let bytes = try CanvasDocumentCodec.encode(fixture.session().document)
        return (CanvasDocumentKeeper(opening: .read(bytes)), bytes)
    }

    private func held(_ keeper: CanvasDocumentKeeper) -> CanvasDocument? {
        if case .document(let document) = keeper.document { return document }
        return nil
    }

    private func outside(_ name: String) throws -> Data {
        var document = fixture.session().document
        document.frames[0].name = name
        return try CanvasDocumentCodec.encode(document)
    }

    private func reload(_ keeper: inout CanvasDocumentKeeper, from disk: Data, copy: String) {
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(disk))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp(copy))
    }

    private func compact(_ document: CanvasDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    @Test func twoOutsideChangesInARowNameBothCopies() throws {
        var (keeper, _) = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside("C1")))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/copy-of-edit"))

        reload(&keeper, from: try outside("C2"), copy: "/work/copy-of-c1")

        #expect(keeper.warning == .reloaded(backups: ["/work/copy-of-edit", "/work/copy-of-c1"], typingKeptIn: []))
        #expect(keeper.warning?.message.contains("copy-of-edit") == true)
        #expect(keeper.warning?.message.contains("copy-of-c1") == true)
    }

    @Test func dismissingForgetsTheCopiesNamedSoFar() throws {
        var (keeper, _) = try opened()
        reload(&keeper, from: try outside("C1"), copy: "/work/one")
        keeper.perform(.dismiss)

        reload(&keeper, from: try outside("C2"), copy: "/work/two")

        #expect(keeper.warning == .reloaded(backups: ["/work/two"], typingKeptIn: []))
    }

    @Test func aFailedSaveDoesNotLoseTheCopiesNamed() throws {
        var (keeper, _) = try opened()
        reload(&keeper, from: try outside("C1"), copy: "/work/one")
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        guard case .save(let data, _) = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        keeper.finish(.writeFailed("disk full"))
        #expect(keeper.warning == .saveFailed("disk full"))

        _ = keeper.apply([fixture.move(fixture.titleID, revision: nil)], by: .owner)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.written(data))

        #expect(keeper.warning == .reloaded(backups: ["/work/one"], typingKeptIn: []))
    }

    @Test func aSaveOverKeepsNamingEarlierCopies() throws {
        var (keeper, _) = try opened()
        reload(&keeper, from: try outside("C1"), copy: "/work/one")
        keeper.perform(.saveOver)
        guard case .save(let data, expecting: nil) = keeper.nextStep() else {
            Issue.record("expected a deliberate save")
            return
        }

        keeper.finish(.savedOver(data, backup: "/work/two"))

        #expect(keeper.warning == .savedOver(backups: ["/work/one", "/work/two"], typingKeptIn: []))
    }

    @Test func anAgentRevisionFromBeforeAReloadConflicts() throws {
        var (keeper, _) = try opened()
        for _ in 0..<3 { _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner) }
        let edited = try #require(held(keeper)?.elements.first { $0.id == fixture.boxID }?.revision)
        let onDisk = try #require(fixture.session().document.elements.first { $0.id == fixture.boxID }?.revision)
        var older = fixture.session().document
        older.frames[0].name = "Checked out"

        reload(&keeper, from: try CanvasDocumentCodec.encode(older), copy: "/work/copy")

        let raised = try #require(held(keeper)?.elements.first { $0.id == fixture.boxID }?.revision)
        #expect(raised > edited)
        for stale in [edited, onDisk] {
            let attempt = keeper.apply([fixture.move(fixture.boxID, revision: stale)], by: .agent)
            guard case .conflict = attempt else {
                Issue.record("revision \(stale) from before the reload went through: \(String(describing: attempt))")
                return
            }
        }
    }

    @Test func aFrameRevisionFromBeforeAReloadConflictsToo() throws {
        var (keeper, _) = try opened()
        let revision = try #require(held(keeper)?.frames.first?.revision)

        reload(&keeper, from: try outside("C1"), copy: "/work/copy")

        let attempt = keeper.apply(
            [.updateFrame(fixture.frameID, expectedRevision: revision, CanvasFramePatch(name: "Agent"))], by: .agent
        )
        guard case .conflict = attempt else {
            Issue.record("the frame's old revision went through: \(String(describing: attempt))")
            return
        }
    }

    @Test func anElementGoneInOneReloadAndBackInTheNextStaysAboveItsOldRevision() throws {
        var (keeper, _) = try opened()
        let revision = try #require(held(keeper)?.elements.first { $0.id == fixture.boxID }?.revision)
        var without = fixture.session().document
        without.elements.removeAll { $0.id == fixture.boxID }
        reload(&keeper, from: try CanvasDocumentCodec.encode(without), copy: "/work/one")

        reload(&keeper, from: try outside("C2"), copy: "/work/two")

        let back = try #require(held(keeper)?.elements.first { $0.id == fixture.boxID }?.revision)
        #expect(back > revision)
    }

    @Test func anElementDeletedBeforeAReloadComesBackAboveTheRevisionInItsHistory() throws {
        var (keeper, _) = try opened()
        for _ in 0..<3 { _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner) }
        let edited = try #require(held(keeper)?.elements.first { $0.id == fixture.boxID }?.revision)
        _ = keeper.apply([.deleteElement(fixture.boxID, expectedRevision: nil)], by: .owner)

        reload(&keeper, from: try outside("C1"), copy: "/work/copy")

        let back = try #require(held(keeper)?.elements.first { $0.id == fixture.boxID }?.revision)
        #expect(back > edited)
    }

    @Test func dismissingARescueLeavesTheCopiesNamed() throws {
        var (keeper, _) = try opened()
        reload(&keeper, from: try outside("C1"), copy: "/work/one")
        let document = try #require(held(keeper))
        let revision = try #require(document.elements.first { $0.id == fixture.titleID }?.revision)
        let original = try #require(document.elements.first { $0.id == fixture.titleID }?.text)
        keeper.setDraft(CanvasTextDraft(elementID: fixture.titleID, original: original, text: original, measuredHeight: 20))
        _ = keeper.apply([.deleteElement(fixture.titleID, expectedRevision: revision)], by: .agent)
        #expect(keeper.warning == .draftRescued)

        keeper.perform(.dismiss)

        #expect(keeper.warning == .reloaded(backups: ["/work/one"], typingKeptIn: []))
    }

    @Test func aReloadClearsAFailedSaveBecauseTheEditsAreInTheCopy() throws {
        var (keeper, _) = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))

        reload(&keeper, from: try outside("C1"), copy: "/work/one")

        #expect(keeper.warning == .reloaded(backups: ["/work/one"], typingKeptIn: []))
        #expect(!keeper.hasStrandedEdits)
    }

    @Test func aBackupFailureInFlightDoesNotPauseSavingAgainAfterASaveOver() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside("C1")))
        #expect(keeper.nextStep() != nil)
        keeper.perform(.saveOver)

        keeper.finish(.backupFailed("disk full"))

        #expect(keeper.warning == nil)
        guard case .save(_, expecting: nil) = keeper.nextStep() else {
            Issue.record("the deliberate save did not go ahead")
            return
        }
    }

    @Test func aRevisionBumpAloneDoesNotAskForACopyOfAFormattingChange() throws {
        var (keeper, _) = try opened()
        keeper.beginEditing(fixture.titleID)
        let disk = try compact(fixture.session().document)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)

        keeper.finish(.read(disk))

        #expect(keeper.nextStep() == nil)
        #expect(keeper.warning == nil)
        #expect(keeper.reloads == 1)
    }

    @Test func editsAreStrandedUntilTheyHaveReachedTheFile() throws {
        var (keeper, _) = try opened()
        #expect(!keeper.hasStrandedEdits)
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        #expect(keeper.hasStrandedEdits)
        guard case .save(let data, _) = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        #expect(keeper.hasStrandedEdits)
        keeper.finish(.written(data))
        #expect(!keeper.hasStrandedEdits)
    }

    @Test func aFailedSaveIsStranded() throws {
        var (keeper, _) = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))
        #expect(keeper.hasStrandedEdits)
    }

    @Test func aReloadWaitingOnItsCopyIsStranded() throws {
        var (keeper, _) = try opened()
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside("C1")))
        #expect(keeper.hasStrandedEdits)
    }

    @Test func aReadInFlightWithNothingChangedIsNotStranded() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        #expect(!keeper.hasStrandedEdits)
    }

    @Test func aHoldWithNothingUnsavedIsNotStranded() throws {
        var (keeper, _) = try opened()
        keeper.beginEditing(fixture.titleID)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(Data("{ not json".utf8)))

        #expect(keeper.warning != nil)
        #expect(!keeper.hasStrandedEdits)
    }

    @Test func anEditUnderAHoldIsStranded() throws {
        var (keeper, _) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(nil))
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)

        #expect(keeper.hasStrandedEdits)
    }
}
