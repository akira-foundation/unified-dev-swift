import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper")
struct CanvasDocumentKeeperTests {
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

    @Test func anEditAsksForASaveExpectingWhatWasRead() throws {
        var (keeper, bytes) = try opened()
        edit(&keeper)

        let step = keeper.nextStep()

        guard case .save(let data, expecting: let expecting) = step else {
            Issue.record("expected a save, got \(String(describing: step))")
            return
        }
        #expect(data != bytes)
        #expect(expecting == [bytes])
    }

    @Test func nothingElseStartsWhileAStepIsInFlight() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        #expect(keeper.nextStep() != nil)
        keeper.perform(.reload)
        edit(&keeper)

        #expect(keeper.nextStep() == nil)
    }

    @Test func aSaveWritesTheLatestDocument() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let first = try #require(savedBytes(keeper.nextStep()))
        _ = keeper.apply([fixture.move(fixture.titleID, revision: nil)], by: .owner)
        keeper.finish(.written(first))

        let second = try #require(savedBytes(keeper.nextStep()))

        #expect(second == (try CanvasDocumentCodec.encode(try #require(held(keeper)))))
        keeper.finish(.written(second))
        #expect(keeper.nextStep() == nil)
    }

    @Test func aReconcileRacingASaveDoesNotReloadTheOwnersEdit() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let writing = try #require(savedBytes(keeper.nextStep()))
        let edited = held(keeper)
        keeper.perform(.reload)
        keeper.finish(.written(writing))

        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(writing))

        #expect(held(keeper) == edited)
        #expect(keeper.warning == nil)
        #expect(keeper.reloads == 0)
    }

    @Test func anEditDuringAReadIsKeptWhenTheDiskTurnsOutToBeOurs() throws {
        var (keeper, bytes) = try opened()
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        edit(&keeper)
        let edited = held(keeper)
        keeper.finish(.read(bytes))

        #expect(held(keeper) == edited)
        #expect(savedBytes(keeper.nextStep()) != nil)
    }

    @Test func lastWrittenChangesOnlyAfterTheWriteSucceeded() throws {
        var (keeper, bytes) = try opened()
        edit(&keeper)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))
        edit(&keeper)

        guard case .save(_, expecting: let expecting) = keeper.nextStep() else {
            Issue.record("the next edit did not try again")
            return
        }
        #expect(expecting?.contains(bytes) == true)
    }

    @Test func aFailedWriteKeepsTheDocumentWarnsAndTriesAgainOnTheNextEdit() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let edited = held(keeper)
        #expect(keeper.nextStep() != nil)

        keeper.finish(.writeFailed("disk full"))

        #expect(held(keeper) == edited)
        #expect(keeper.warning == .saveFailed("disk full"))
        #expect(keeper.nextStep() == nil)

        _ = keeper.apply([fixture.move(fixture.titleID, revision: nil)], by: .owner)
        let retry = try #require(savedBytes(keeper.nextStep()))
        let latest = try CanvasDocumentCodec.encode(try #require(held(keeper)))
        #expect(retry == latest)
        keeper.finish(.written(retry))
        #expect(keeper.warning == nil)
    }

    @Test func aFailedWriteThatLandedAfterAllIsNotAnOutsideChange() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        let attempted = try #require(savedBytes(keeper.nextStep()))
        keeper.finish(.writeFailed("ambiguous"))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)

        keeper.finish(.read(attempted))

        #expect(keeper.reloads == 0)
        #expect(keeper.warning == nil)
        #expect(keeper.nextStep() == nil)
    }

    @Test func anOutsideChangeFoundBySavingIsReconciledRatherThanOverwritten() throws {
        var (keeper, _) = try opened()
        edit(&keeper)
        #expect(keeper.nextStep() != nil)

        keeper.finish(.outsideChange)

        #expect(keeper.nextStep() == .read)
    }
}
