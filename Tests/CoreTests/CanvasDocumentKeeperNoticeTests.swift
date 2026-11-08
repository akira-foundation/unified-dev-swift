import Foundation
import Testing
@testable import Core

@Suite("CanvasDocumentKeeper notices")
struct CanvasDocumentKeeperNoticeTests {
    private let fixture = CanvasSessionFixture()

    private func outside(_ name: String, removingTitle: Bool = false) throws -> Data {
        var document = fixture.session().document
        document.frames[0].name = name
        if removingTitle { document.elements.removeAll { $0.id == fixture.titleID } }
        return try CanvasDocumentCodec.encode(document)
    }

    private func reload(_ keeper: inout CanvasDocumentKeeper, from disk: Data, copy: String) {
        keeper.perform(.reload)
        #expect(keeper.nextStep() == .read)
        keeper.finish(.read(disk))
        #expect(keeper.nextStep() != nil)
        keeper.finish(.backedUp(copy))
    }

    private func draftingKeeper() throws -> CanvasDocumentKeeper {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(fixture.session().document)))
        let typed = CanvasText(runs: [CanvasTextRun(text: "typed", fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")])
        let original = try #require(fixture.session().document.elements.first { $0.id == fixture.titleID }?.text)
        keeper.setDraft(CanvasTextDraft(elementID: fixture.titleID, original: original, text: typed, measuredHeight: 20))
        return keeper
    }

    @Test func aSecondReloadStillNamesTheCopyHoldingTheTypedText() throws {
        var keeper = try draftingKeeper()
        reload(&keeper, from: try outside("C1", removingTitle: true), copy: "/work/first")

        reload(&keeper, from: try outside("C2", removingTitle: true), copy: "/work/second")

        #expect(keeper.warning == .reloaded(backups: ["/work/first", "/work/second"], typingKeptIn: ["/work/first"]))
        let sentence = try #require(keeper.warning?.message.components(separatedBy: "your text is in ").last)
        #expect(sentence == "first.")
    }

    @Test func onlyTheCopyTakenWhenTheElementWentHoldsTheTypedText() throws {
        var keeper = try draftingKeeper()
        reload(&keeper, from: try outside("C1"), copy: "/work/first")

        reload(&keeper, from: try outside("C2", removingTitle: true), copy: "/work/second")

        #expect(keeper.warning == .reloaded(backups: ["/work/first", "/work/second"], typingKeptIn: ["/work/second"]))
    }

    @Test func aSaveOverKeepsNamingTheCopyHoldingTheTypedText() throws {
        var keeper = try draftingKeeper()
        reload(&keeper, from: try outside("C1", removingTitle: true), copy: "/work/first")
        keeper.perform(.saveOver)
        guard case .save(let data, expecting: nil) = keeper.nextStep() else {
            Issue.record("expected a deliberate save")
            return
        }

        keeper.finish(.savedOver(data, backup: "/work/second"))

        #expect(keeper.warning?.message.contains("your text is in first.") == true)
    }

    @Test func aSaveOverCopyLeftBehindByAFailedWriteIsNamed() throws {
        var keeper = CanvasDocumentKeeper(opening: .read(try CanvasDocumentCodec.encode(fixture.session().document)))
        keeper.perform(.saveOver)
        #expect(keeper.nextStep() != nil)

        keeper.finish(.saveOverFailed("disk full", backup: "/work/left-behind"))

        #expect(keeper.warning?.message.contains("left-behind") == true)
        _ = keeper.apply([fixture.move(fixture.boxID, revision: nil)], by: .owner)
        guard case .save(let data, _) = keeper.nextStep() else {
            Issue.record("expected a save")
            return
        }
        keeper.finish(.written(data))
        #expect(keeper.warning == .copyKept(backups: ["/work/left-behind"], typingKeptIn: []))
        #expect(keeper.warning?.message.contains("left-behind") == true)
        #expect(keeper.warning?.title == "A copy of this canvas was kept")
        #expect(keeper.warning?.message.contains("not replaced") == false)
    }

    @Test func focusReturnsOnlyFromTheClosingEditorOrFromNothing() {
        #expect(CanvasEditing.returnsFocus(from: .nothing))
        #expect(CanvasEditing.returnsFocus(from: .closingEditor))
        #expect(!CanvasEditing.returnsFocus(from: .somethingElse))
    }

    @Test(arguments: ["pt_PT", "en_GB"])
    func aTypedNumberParsesInTheLocaleItIsShownIn(identifier: String) {
        let format = FloatingPointFormatStyle<Double>(locale: Locale(identifier: identifier)).precision(.fractionLength(0...1))

        #expect(CanvasEditing.number(from: 12.5.formatted(format), format: format) == 12.5)
    }

    @Test func somethingThatIsNotANumberIsNoNumber() {
        let format = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_GB"))

        #expect(CanvasEditing.number(from: "abc", format: format) == nil)
        #expect(CanvasEditing.number(from: "", format: format) == nil)
    }
}
