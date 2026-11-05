import Foundation
import Testing
@testable import Core

@Suite("CanvasEditing")
struct CanvasEditingTests {
    private let frameID = CanvasFrameID("f")

    private func run(_ text: String) -> CanvasTextRun {
        CanvasTextRun(text: text, fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")
    }

    private func document(note: Bool = false) -> CanvasDocument {
        let text = CanvasText(runs: [run("hi")])
        return CanvasDocument(
            frames: [
                CanvasFrame(id: frameID, name: "One", rect: CanvasRect(x: 100, y: 50, width: 500, height: 400)),
                CanvasFrame(name: "Two", rect: CanvasRect(x: 700, y: 50, width: 500, height: 400)),
            ],
            elements: [CanvasElement(
                id: CanvasElementID("t"), frameID: frameID,
                rect: CanvasRect(x: 10, y: 10, width: 200, height: 50), kind: note ? .note(text) : .text(text)
            )]
        )
    }

    private func applied(_ operations: [CanvasOperation], to document: CanvasDocument) -> CanvasElement? {
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        return session.document.elements.first { $0.id == CanvasElementID("t") }
    }

    private func finish(_ edited: CanvasText, measured: Double, in document: CanvasDocument) -> [CanvasOperation] {
        CanvasEditing.operations(
            finishing: CanvasElementID("t"), original: CanvasText(runs: [run("hi")]), edited: edited, measuredHeight: measured, in: document
        )
    }

    @Test func anUnchangedTextMakesNoOperation() {
        #expect(finish(CanvasText(runs: [run("hi")]), measured: 500, in: document()).isEmpty)
    }

    @Test func anEmptyEditKeepsTheElement() {
        let document = document()
        let element = applied(finish(CanvasText(runs: [run("")]), measured: 10, in: document), to: document)
        #expect(element != nil)
        #expect(element?.text?.runs.map(\.text) == [""])
    }

    @Test func finishingGrowsTheHeightAndNeverShrinksIt() {
        let document = document()
        let grown = applied(finish(CanvasText(runs: [run("bigger")]), measured: 120, in: document), to: document)
        let kept = applied(finish(CanvasText(runs: [run("bigger")]), measured: 20, in: document), to: document)
        #expect(grown?.rect.size.height == 120)
        #expect(kept?.rect.size.height == 50)
    }

    @Test func aNoteStaysANote() {
        let document = document(note: true)
        let element = applied(finish(CanvasText(runs: [run("changed")]), measured: 10, in: document), to: document)
        #expect(element?.isNote == true)
        #expect(element?.text?.runs.map(\.text) == ["changed"])
    }

    @Test func aMissingElementMakesNoOperation() {
        let operations = CanvasEditing.operations(
            finishing: CanvasElementID("nope"), original: CanvasText(runs: [run("a")]), edited: CanvasText(runs: [run("b")]),
            measuredHeight: 10, in: document()
        )
        #expect(operations.isEmpty)
    }

    @Test func aNewTextLandsInTheFrameUnderThePointAndIsClamped() {
        let element = CanvasEditing.newText(at: CanvasPoint(x: 400, y: 100), in: document())
        #expect(element.frameID == frameID)
        #expect(element.rect.origin == CanvasPoint(x: 300, y: 50))
        #expect(element.rect.size.width == 200)
    }

    @Test func aNewTextKeepsItsDefaultWidthWhenThereIsRoom() {
        let element = CanvasEditing.newText(at: CanvasPoint(x: 110, y: 60), in: document())
        #expect(element.rect.size.width == 490)
        let wide = CanvasEditing.newText(at: CanvasPoint(x: 100, y: 60), in: CanvasDocument(frames: [
            CanvasFrame(name: "Wide", rect: CanvasRect(x: 100, y: 50, width: 2000, height: 400)),
        ]))
        #expect(wide.rect.size.width == 640)
    }

    @Test func aPointOutsideEveryFrameMakesAFreeElement() {
        let element = CanvasEditing.newText(at: CanvasPoint(x: 5_000, y: 5_000), in: document())
        #expect(element.frameID == nil)
        #expect(element.rect.origin == CanvasPoint(x: 5_000, y: 5_000))
    }

    @Test func theImageTargetIsTheFrameUnderTheCentreThenTheFirst() {
        let document = document()
        #expect(CanvasEditing.imageTarget(centre: CanvasPoint(x: 800, y: 100), in: document)?.name == "Two")
        #expect(CanvasEditing.imageTarget(centre: CanvasPoint(x: -900, y: 0), in: document)?.name == "One")
        #expect(CanvasEditing.imageTarget(centre: CanvasPoint(x: 0, y: 0), in: CanvasDocument()) == nil)
    }
}

@Suite("CanvasFrameSize")
struct CanvasFrameSizeTests {
    @Test func sizesAreClampedToOneAndEightThousandOneHundredNinetyTwo() {
        #expect(CanvasFrameSize.clamped(CanvasSize(width: 0, height: -5)) == CanvasSize(width: 1, height: 1))
        #expect(CanvasFrameSize.clamped(CanvasSize(width: 99_999, height: 8_192)) == CanvasSize(width: 8_192, height: 8_192))
        #expect(CanvasFrameSize.clamped(CanvasSize(width: 1_080, height: 1_350)) == CanvasSize(width: 1_080, height: 1_350))
    }

    @Test func resizingKeepsTheOriginAndClamps() {
        let frame = CanvasFrame(name: "A", rect: CanvasRect(x: 30, y: 40, width: 100, height: 100))
        let document = CanvasDocument(frames: [frame])
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(CanvasFrameSize.operations(resizing: frame.id, to: CanvasSize(width: 50_000, height: 0), in: document), by: .owner)
        #expect(session.document.frames.first?.rect == CanvasRect(x: 30, y: 40, width: 8_192, height: 1))
    }

    @Test func resizingToTheSameSizeMakesNoOperation() {
        let frame = CanvasFrame(name: "A", rect: CanvasRect(x: 0, y: 0, width: 100, height: 100))
        #expect(CanvasFrameSize.operations(resizing: frame.id, to: CanvasSize(width: 100, height: 100), in: CanvasDocument(frames: [frame])).isEmpty)
    }
}

@Suite("CanvasCoalescedCommit")
@MainActor
struct CanvasCoalescedCommitTests {
    private func settle() async {
        for _ in 0..<100 { await Task.yield() }
    }

    @Test func rapidChangesCommitOnceWithTheLastValue() async {
        let gates = CanvasCommitGates()
        var committed: [Int] = []
        let coalescer = CanvasCoalescedCommit(sleep: { _ in await gates.wait() })
        for value in 1...5 { coalescer.schedule { committed.append(value) } }
        await gates.releaseAll(expecting: 5)
        await settle()
        #expect(committed == [5])
    }

    @Test func aChangeDoesNotCommitUntilItsWaitIsOver() async {
        let gates = CanvasCommitGates()
        var committed: [Int] = []
        let coalescer = CanvasCoalescedCommit(sleep: { _ in await gates.wait() })
        coalescer.schedule { committed.append(1) }
        await gates.reach(1)
        await settle()
        let whileWaiting = committed
        await gates.releaseAll(expecting: 1)
        await settle()
        #expect(whileWaiting.isEmpty)
        #expect(committed == [1])
    }

    @Test func aLaterChangeRestartsTheWait() async {
        let gates = CanvasCommitGates()
        var committed: [Int] = []
        let coalescer = CanvasCoalescedCommit(sleep: { _ in await gates.wait() })
        coalescer.schedule { committed.append(1) }
        coalescer.schedule { committed.append(2) }
        await gates.reach(2)
        gates.release(0)
        await settle()
        let afterTheFirstWait = committed
        gates.release(1)
        await settle()
        #expect(afterTheFirstWait.isEmpty)
        #expect(committed == [2])
    }

    @Test func flushingCommitsAtOnceAndOnlyOnce() async {
        let gates = CanvasCommitGates()
        var committed: [Int] = []
        let coalescer = CanvasCoalescedCommit(sleep: { _ in await gates.wait() })
        coalescer.schedule { committed.append(1) }
        coalescer.flush()
        let immediate = committed
        await gates.releaseAll(expecting: 1)
        await settle()
        coalescer.flush()
        #expect(immediate == [1])
        #expect(committed == [1])
    }

    @Test func aFlushEndsTheWaitItInterrupted() async {
        let gates = CanvasCommitGates()
        var committed: [Int] = []
        let coalescer = CanvasCoalescedCommit(sleep: { _ in await gates.wait() })
        coalescer.schedule { committed.append(1) }
        coalescer.flush()
        coalescer.schedule { committed.append(2) }
        await gates.reach(2)
        gates.release(0)
        await settle()
        let afterTheOldWait = committed
        gates.release(1)
        await settle()
        #expect(afterTheOldWait == [1])
        #expect(committed == [1, 2])
    }
}

@MainActor
private final class CanvasCommitGates {
    private var waiting: [CheckedContinuation<Void, Never>?] = []

    func wait() async {
        await withCheckedContinuation { waiting.append($0) }
    }

    func reach(_ count: Int) async {
        while waiting.count < count { await Task.yield() }
    }

    func release(_ index: Int) {
        waiting[index]?.resume()
        waiting[index] = nil
    }

    func releaseAll(expecting count: Int) async {
        await reach(count)
        for index in waiting.indices { release(index) }
    }
}
