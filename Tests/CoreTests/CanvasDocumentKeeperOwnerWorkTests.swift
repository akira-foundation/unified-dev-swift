import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper copies of the owner's work")
struct CanvasDocumentKeeperOwnerWorkTests {
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

    private func agentEdit(_ keeper: inout CanvasDocumentKeeper) {
        guard case .document(let document) = keeper.document,
              let revision = document.elements.first(where: { $0.id == fixture.boxID })?.revision else {
            Issue.record("the fixture has no box")
            return
        }
        _ = keeper.apply([fixture.move(fixture.boxID, revision: revision)], by: .agent)
    }

    private func written(_ keeper: inout CanvasDocumentKeeper) {
        guard case .save(let data, _) = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        keeper.finish(.written(data))
    }

    private func titleDraft(_ words: String, on keeper: CanvasDocumentKeeper) throws -> CanvasTextDraft {
        guard case .document(let document) = keeper.document,
              let original = document.elements.first(where: { $0.id == fixture.titleID })?.text else {
            throw CancellationError()
        }
        let text = CanvasText(runs: [CanvasTextRun(text: words, fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")])
        return CanvasTextDraft(elementID: fixture.titleID, original: original, text: text, measuredHeight: 20)
    }

    private func held(_ keeper: CanvasDocumentKeeper) throws -> CanvasDocument {
        guard case .document(let document) = keeper.document else { throw CancellationError() }
        return document
    }

    private func compact(_ document: CanvasDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    private func copyInFlight(_ keeper: inout CanvasDocumentKeeper) throws {
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside("C1")))
        #expect(keeper.nextStep() != nil)
    }

    @Test func aFormattingRewriteKeepsTheMarkForTheNextCopy() throws {
        var keeper = try opened()
        edit(&keeper)
        written(&keeper)
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try compact(held(keeper))))
        #expect(keeper.nextStep() == nil)
        #expect(keeper.reloads == 1)

        reload(&keeper, from: try outside("C1"), copy: "/work/real")

        #expect(keeper.copiesHoldingOwnerWork == ["/work/real"])
    }

    @Test func aCopySupersededByAnUndoStillHoldsTheOwnersEdit() throws {
        var keeper = try opened()
        edit(&keeper)
        try copyInFlight(&keeper)
        let undone = keeper.undo()
        #expect(undone)

        keeper.finish(.backedUp("/work/first"))

        #expect(keeper.copiesHoldingOwnerWork == ["/work/first"])
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/second"))
        #expect(keeper.copiesHoldingOwnerWork == ["/work/first", "/work/second"])
    }

    @Test func aCopyTakenBeforeTheOwnersUndoHoldsOnlyTheAgentsEdit() throws {
        var keeper = try opened()
        agentEdit(&keeper)
        try copyInFlight(&keeper)
        let undone = keeper.undo()
        #expect(undone)

        keeper.finish(.backedUp("/work/agent"))

        #expect(keeper.copiesHoldingOwnerWork.isEmpty)
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/undo"))
        #expect(keeper.copiesHoldingOwnerWork == ["/work/undo"])
    }

    @Test func anEditWrittenThenReplacedFromOutsideIsAsked() throws {
        var keeper = try opened()
        edit(&keeper)
        written(&keeper)

        reload(&keeper, from: try outside("C1"), copy: "/work/edit")

        #expect(!keeper.hasStrandedEdits)
        #expect(keeper.copiesHoldingOwnerWork == ["/work/edit"])
    }

    @Test func anAgentEditWrittenThenReplacedDoesNotAsk() throws {
        var keeper = try opened()
        agentEdit(&keeper)
        written(&keeper)

        reload(&keeper, from: try outside("C1"), copy: "/work/agent")

        #expect(keeper.warning?.message.contains("agent") == true)
        #expect(keeper.copiesHoldingOwnerWork.isEmpty)
    }

    @Test func anAgentEditNotYetWrittenThenReplacedDoesNotAsk() throws {
        var keeper = try opened()
        agentEdit(&keeper)

        reload(&keeper, from: try outside("C1"), copy: "/work/agent")

        #expect(keeper.copiesHoldingOwnerWork.isEmpty)
    }

    @Test func anUndoThenReplacedIsAsked() throws {
        var keeper = try opened()
        agentEdit(&keeper)
        let undone = keeper.undo()
        #expect(undone)
        written(&keeper)

        reload(&keeper, from: try outside("C1"), copy: "/work/undo")

        #expect(keeper.copiesHoldingOwnerWork == ["/work/undo"])
    }

    @Test func aRescuedDraftIsAsked() throws {
        var keeper = try opened()
        guard case .document(let document) = keeper.document,
              let revision = document.elements.first(where: { $0.id == fixture.titleID })?.revision else {
            Issue.record("the fixture has no title")
            return
        }
        keeper.setDraft(try titleDraft("typed by hand", on: keeper))
        _ = keeper.apply([.deleteElement(fixture.titleID, expectedRevision: revision)], by: .agent)
        #expect(keeper.warning == .draftRescued)
        keeper.finishDraft()
        written(&keeper)

        reload(&keeper, from: try outside("C1"), copy: "/work/rescued")

        #expect(keeper.copiesHoldingOwnerWork == ["/work/rescued"])
    }

    @Test func theMarkClearsAfterTheReload() throws {
        var keeper = try opened()
        edit(&keeper)
        written(&keeper)
        reload(&keeper, from: try outside("C1"), copy: "/work/edit")
        #expect(keeper.copiesHoldingOwnerWork == ["/work/edit"])

        reload(&keeper, from: try outside("C2"), copy: "/work/plain")

        #expect(keeper.warning == .reloaded(backups: ["/work/edit", "/work/plain"], typingKeptIn: []))
        #expect(keeper.copiesHoldingOwnerWork == ["/work/edit"])
    }
}
