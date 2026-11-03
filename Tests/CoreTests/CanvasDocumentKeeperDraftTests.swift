import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper drafts")
struct CanvasDocumentKeeperDraftTests {
    private let fixture = CanvasSessionFixture()

    private func opened() throws -> CanvasDocumentKeeper {
        CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(fixture.session().document)))
    }

    private func held(_ keeper: CanvasDocumentKeeper) -> CanvasDocument? {
        if case .document(let document) = keeper.document { return document }
        return nil
    }

    private func typed(_ words: String) -> CanvasText {
        CanvasText(runs: [CanvasTextRun(text: words, fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")])
    }

    private func draft(_ words: String, on keeper: CanvasDocumentKeeper) -> CanvasTextDraft? {
        guard let original = held(keeper)?.elements.first(where: { $0.id == fixture.titleID })?.text else { return nil }
        return CanvasTextDraft(elementID: fixture.titleID, original: original, text: typed(words), measuredHeight: 20)
    }

    private func outside(removingTitle: Bool) throws -> Data {
        var document = fixture.session().document
        document.frames[0].name = "From git"
        if removingTitle { document.elements.removeAll { $0.id == fixture.titleID } }
        return try CanvasDocumentCodec.encode(document)
    }

    private func text(ofTitleIn document: CanvasDocument?) -> CanvasText? {
        document?.elements.first { $0.id == fixture.titleID }?.text
    }

    private func decoded(_ step: CanvasDiskStep?) -> CanvasDocument? {
        guard case .backup(let data) = step, case .document(let document) = CanvasDocumentCodec.decode(data) else { return nil }
        return document
    }

    @Test func aDraftIsInTheBackupWhenAReloadRemovesItsElement() throws {
        var keeper = try opened()
        keeper.setDraft(draft("typed by hand", on: keeper))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside(removingTitle: true)))

        let backup = decoded(keeper.nextStep())
        #expect(text(ofTitleIn: backup) == typed("typed by hand"))

        keeper.finish(.backedUp("/work/copy"))

        #expect(keeper.draft == nil)
        #expect(text(ofTitleIn: held(keeper)) == nil)
        #expect(keeper.warning == .reloaded(backups: ["/work/copy"], typingKeptIn: ["/work/copy"]))
        #expect(keeper.warning?.message.contains("your text") == true)
    }

    @Test func typingDuringTheBackupGoesIntoAnotherCopy() throws {
        var keeper = try opened()
        keeper.setDraft(draft("first", on: keeper))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside(removingTitle: true)))
        #expect(keeper.nextStep() != nil)
        keeper.setDraft(draft("first and more", on: keeper))

        keeper.finish(.backedUp("/work/first"))

        let again = decoded(keeper.nextStep())
        #expect(text(ofTitleIn: again) == typed("first and more"))
    }

    @Test func aDraftOutlivesAReloadThatKeepsItsElement() throws {
        var keeper = try opened()
        keeper.setDraft(draft("typed by hand", on: keeper))
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(try outside(removingTitle: false)))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp("/work/copy"))
        #expect(keeper.draft != nil)
        #expect(keeper.warning == .reloaded(backups: ["/work/copy"], typingKeptIn: []))

        keeper.finishDraft()

        #expect(text(ofTitleIn: held(keeper)) == typed("typed by hand"))
        #expect(held(keeper)?.frames[0].name == "From git")
    }

    @Test func finishingADraftIsOneStepAndIsSaved() throws {
        var keeper = try opened()
        keeper.setDraft(draft("typed by hand", on: keeper))

        keeper.finishDraft()

        #expect(keeper.undoDepth == 1)
        #expect(keeper.draft == nil)
        guard case .save = keeper.nextStep() else {
            Issue.record("a finished draft was not saved")
            return
        }
    }

    @Test func aDraftThatChangedNothingIsNoStep() throws {
        var keeper = try opened()
        let original = try #require(text(ofTitleIn: held(keeper)))
        keeper.setDraft(CanvasTextDraft(elementID: fixture.titleID, original: original, text: original, measuredHeight: 20))

        keeper.finishDraft()

        #expect(keeper.undoDepth == 0)
        #expect(keeper.nextStep() == nil)
    }

    @Test func anAgentDeletingTheElementBeingTypedInDoesNotDiscardTheText() throws {
        var keeper = try opened()
        let revision = try #require(held(keeper)?.elements.first { $0.id == fixture.titleID }?.revision)
        keeper.setDraft(draft("typed by hand", on: keeper))

        _ = keeper.apply([.deleteElement(fixture.titleID, expectedRevision: revision)], by: .agent)

        #expect(keeper.warning == .draftRescued)
        #expect(held(keeper)?.elements.contains { $0.id == fixture.titleID } == true)
        keeper.finishDraft()
        #expect(text(ofTitleIn: held(keeper)) == typed("typed by hand"))
        keeper.perform(.dismiss)
        #expect(keeper.warning == nil)
    }

    @Test func anUndoRemovingTheFrameBeingTypedInKeepsTheTextWhereItWas() throws {
        var keeper = try opened()
        let frame = CanvasFrame(id: CanvasFrameID("added"), name: "Added", rect: CanvasRect(x: 300, y: 400, width: 100, height: 100))
        let element = CanvasElement(
            id: CanvasElementID("note"), frameID: frame.id,
            rect: CanvasRect(x: 5, y: 6, width: 50, height: 20), kind: .text(typed("start"))
        )
        _ = keeper.apply([.addFrame(frame), .addElement(element)], by: .owner)
        keeper.setDraft(CanvasTextDraft(elementID: element.id, original: typed("start"), text: typed("more"), measuredHeight: 20))

        let undone = keeper.undo()
        #expect(undone)

        let rescued = try #require(held(keeper)?.elements.first { $0.id == element.id })
        #expect(rescued.frameID == nil)
        #expect(rescued.rect.origin == CanvasPoint(x: 305, y: 406))
        #expect(rescued.text == typed("more"))
    }
}
