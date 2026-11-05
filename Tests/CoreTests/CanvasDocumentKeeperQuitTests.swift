import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper quitting and retrying")
struct CanvasDocumentKeeperQuitTests {
    private let fixture = CanvasSessionFixture()

    private func opened() throws -> CanvasDocumentKeeper {
        CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(fixture.session().document)))
    }

    private func outside(_ name: String) throws -> Data {
        var document = fixture.session().document
        document.frames[0].name = name
        return try CanvasDocumentCodec.encode(document)
    }

    private func edit(_ keeper: inout CanvasDocumentKeeper) {
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
    }

    private func reload(_ keeper: inout CanvasDocumentKeeper, from disk: Data, copy: String) {
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(disk))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp(copy))
    }

    private func failedSaveOver(_ keeper: inout CanvasDocumentKeeper, result: CanvasDiskResult) {
        keeper.perform(.saveOver)
        #expect(keeper.nextStep() != nil)
        keeper.finish(result)
    }

    private func expectation(of step: CanvasDiskStep?) -> [Data]?? {
        if case .save(_, let expecting) = step { return .some(expecting) }
        return nil
    }

    @Test func aReloadOverAnEditKeepsItsCopyForTheQuitQuestionEvenThoughNothingIsStranded() throws {
        var keeper = try opened()
        edit(&keeper)

        reload(&keeper, from: try outside("C1"), copy: "/work/edit")

        #expect(!keeper.hasStrandedEdits)
        #expect(keeper.copiesHoldingOwnerWork == ["/work/edit"])
    }

    @Test func aPlainReloadWithNoEditDoesNotAsk() throws {
        var keeper = try opened()

        reload(&keeper, from: try outside("C1"), copy: "/work/plain")

        #expect(keeper.warning?.message.contains("plain") == true)
        #expect(keeper.copiesHoldingOwnerWork.isEmpty)
    }

    @Test func aPlainReloadAfterAnEditedOneAddsNothingToTheQuestion() throws {
        var keeper = try opened()
        edit(&keeper)
        reload(&keeper, from: try outside("C1"), copy: "/work/edit")

        reload(&keeper, from: try outside("C2"), copy: "/work/plain")

        #expect(keeper.copiesHoldingOwnerWork == ["/work/edit"])
    }

    @Test func dismissingTheNoticeStopsTheQuestion() throws {
        var keeper = try opened()
        edit(&keeper)
        reload(&keeper, from: try outside("C1"), copy: "/work/edit")

        keeper.perform(.dismiss)

        #expect(keeper.copiesHoldingOwnerWork.isEmpty)
    }

    @Test func aSaveOverDoesNotForgetTheCopyOfAnEarlierEdit() throws {
        var keeper = try opened()
        edit(&keeper)
        reload(&keeper, from: try outside("C1"), copy: "/work/edit")
        keeper.perform(.saveOver)
        guard case .save(let data, expecting: nil) = keeper.nextStep() else {
            Issue.record("expected a deliberate save")
            return
        }

        keeper.finish(.savedOver(data, backup: "/work/disk"))

        #expect(keeper.copiesHoldingOwnerWork == ["/work/edit"])
    }

    @Test func tryAgainRepeatsASaveOverThatLeftACopy() throws {
        var keeper = try opened()
        failedSaveOver(&keeper, result: .saveOverFailed("disk full", backup: "/work/copy"))

        keeper.perform(.tryAgain)

        #expect(expectation(of: keeper.nextStep()) == .some(nil))
    }

    @Test func tryAgainRepeatsASaveOverThatFailedWithNoCopy() throws {
        var keeper = try opened()
        failedSaveOver(&keeper, result: .writeFailed("disk full"))

        keeper.perform(.tryAgain)

        #expect(expectation(of: keeper.nextStep()) == .some(nil))
    }

    @Test func tryAgainAfterAnOrdinaryFailureIsStillCompareAndSwap() throws {
        var keeper = try opened()
        edit(&keeper)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))

        keeper.perform(.tryAgain)

        guard case .save(_, let expecting?) = keeper.nextStep() else {
            Issue.record("expected a compared save")
            return
        }
        #expect(!expecting.isEmpty)
    }

    @Test func aSaveOverThatLandedLeavesTryAgainComparing() throws {
        var keeper = try opened()
        edit(&keeper)
        keeper.perform(.saveOver)
        guard case .save(let data, expecting: nil) = keeper.nextStep() else {
            Issue.record("expected a deliberate save")
            return
        }
        keeper.finish(.written(data))
        edit(&keeper)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))

        keeper.perform(.tryAgain)

        guard case .save(_, .some) = keeper.nextStep() else {
            Issue.record("expected a compared save")
            return
        }
    }

    @Test func aRefusedSaveOverLeavesTryAgainComparing() throws {
        var keeper = try opened()
        failedSaveOver(&keeper, result: .saveOverRefused("no copy could be made"))
        let bytes = try CanvasDocumentCodec.encode(fixture.session().document)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(bytes))
        edit(&keeper)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.writeFailed("disk full"))

        keeper.perform(.tryAgain)

        guard case .save(_, .some) = keeper.nextStep() else {
            Issue.record("expected a compared save")
            return
        }
    }

    @Test func twoFailedSaveOversNameBothCopies() throws {
        var keeper = try opened()
        failedSaveOver(&keeper, result: .saveOverFailed("disk full", backup: "/work/first"))
        failedSaveOver(&keeper, result: .saveOverFailed("disk full", backup: "/work/second"))
        keeper.perform(.saveOver)
        guard case .save(let data, expecting: nil) = keeper.nextStep() else {
            Issue.record("expected a deliberate save")
            return
        }

        keeper.finish(.written(data))

        #expect(keeper.warning == .copyKept(backups: ["/work/first", "/work/second"], typingKeptIn: []))
    }

    @Test func aCopyOutdatedByAnEditDuringTheBackupIsStillNamed() throws {
        var keeper = try opened()
        edit(&keeper)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside("C1")))
        #expect(keeper.nextStep() != nil)
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)

        keeper.finish(.backedUp("/work/outdated"))

        #expect(keeper.warning == .copyKept(backups: ["/work/outdated"], typingKeptIn: []))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/latest"))
        #expect(keeper.warning == .reloaded(backups: ["/work/outdated", "/work/latest"], typingKeptIn: []))
        #expect(keeper.copiesHoldingOwnerWork == ["/work/outdated", "/work/latest"])
    }

    @Test func aCopyFinishedAfterASaveOverTookItsPlaceIsStillNamed() throws {
        var keeper = try opened()
        edit(&keeper)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside("C1")))
        #expect(keeper.nextStep() != nil)
        keeper.perform(.saveOver)

        keeper.finish(.backedUp("/work/in-flight"))

        #expect(keeper.warning?.message.contains("in-flight") == true)
    }

    @Test func noQuestionWithNothingToAsk() {
        #expect(CanvasQuitQuestion(stranded: [], copiesOfOwnerWork: []) == nil)
    }

    @Test func theQuestionNamesTheCopyOnItsOwn() throws {
        let question = try #require(CanvasQuitQuestion(stranded: [], copiesOfOwnerWork: ["/work/deck.backup-1.udcanvas"]))

        #expect(question.title == "Your canvas edits are in a copy")
        #expect(question.detail.contains("deck.backup-1.udcanvas"))
        #expect(!question.detail.contains("/work"))
        #expect(!question.detail.contains("have not reached the file"))
    }

    @Test func theQuestionCarriesBothWhenBothApply() throws {
        let question = try #require(CanvasQuitQuestion(stranded: ["/work/a.udcanvas", "/work/b.udcanvas"], copiesOfOwnerWork: ["/work/c.backup"]))

        #expect(question.title == "2 canvases have edits that are not saved")
        #expect(question.detail.contains("a.udcanvas"))
        #expect(question.detail.contains("have not reached the file"))
        #expect(question.detail.contains("c.backup"))
    }
}
