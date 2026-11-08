import Foundation
import Testing
@testable import Core

@Suite("Selecting a frame or its elements")
struct CanvasFrameSelectionTests {
    private static let one = CanvasFrame(id: CanvasFrameID("one"), name: "One", rect: CanvasRect(x: 0, y: 0, width: 500, height: 500))
    private static let two = CanvasFrame(id: CanvasFrameID("two"), name: "Two", rect: CanvasRect(x: 600, y: 0, width: 500, height: 500))
    private static let box = CanvasElement(
        id: CanvasElementID("box"), frameID: one.id, rect: CanvasRect(x: 10, y: 10, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
    )
    private static let spare = CanvasElement(
        id: CanvasElementID("spare"), frameID: one.id, rect: CanvasRect(x: 100, y: 10, width: 50, height: 50), kind: .shape(CanvasShape(kind: .rectangle))
    )
    private let document = CanvasDocument(frames: [one, two], elements: [box, spare])
    private let inside = CanvasPoint(x: 300, y: 300)
    private let outside = CanvasPoint(x: 550, y: 900)

    @Test func pressingANameSelectsTheFrameAndGetsReadyToMoveIt() {
        let press = CanvasSelection().pressed(label: Self.one.id, element: nil, at: inside, extending: false, in: document)
        #expect(press.selection == CanvasSelection(frame: Self.one.id))
        #expect(press.dragging == .frame(Self.one.id))
    }

    @Test func aFrameAndElementsAreNeverSelectedTogether() {
        let press = CanvasSelection(elements: [Self.box.id]).pressed(label: Self.two.id, element: nil, at: inside, extending: true, in: document)
        #expect(press.selection.elements.isEmpty && press.selection.frame == Self.two.id)
        let again = press.selection.pressed(label: nil, element: Self.box.id, at: inside, extending: false, in: document)
        #expect(again.selection.frame == nil && again.selection.elements == [Self.box.id])
        #expect(CanvasSelection(elements: [Self.box.id], frame: Self.one.id).elements.isEmpty)
    }

    @Test func pressingAnElementOfASelectedFrameMovesTheElementAndNotTheFrame() {
        let press = CanvasSelection(frame: Self.one.id).pressed(label: nil, element: Self.box.id, at: inside, extending: false, in: document)
        #expect(press.dragging == .elements([Self.box.id]))
    }

    @Test func pressingEmptySpaceInsideASelectedFrameKeepsItAndMovesIt() {
        let press = CanvasSelection(frame: Self.one.id).pressed(label: nil, element: nil, at: inside, extending: false, in: document)
        #expect(press.selection.frame == Self.one.id)
        #expect(press.dragging == .frame(Self.one.id))
    }

    @Test func extendingOverASelectedFrameKeepsItAndMovesNothing() {
        let press = CanvasSelection(frame: Self.one.id).pressed(label: nil, element: nil, at: inside, extending: true, in: document)
        #expect(press.selection.frame == Self.one.id)
        #expect(press.dragging == .nothing)
    }

    @Test func aNameWinsOverAnElementUnderTheSamePress() {
        let press = CanvasSelection().pressed(label: Self.two.id, element: Self.box.id, at: inside, extending: false, in: document)
        #expect(press.selection == CanvasSelection(frame: Self.two.id))
        #expect(press.dragging == .frame(Self.two.id))
    }

    @Test func pressingEmptySpaceInsideAFrameNotSelectedDoesNotSelectIt() {
        let press = CanvasSelection(frame: Self.two.id).pressed(label: nil, element: nil, at: inside, extending: false, in: document)
        #expect(press.selection.isEmpty)
        #expect(press.dragging == .nothing)
    }

    @Test func pressingOutsideClearsUnlessExtending() {
        let cleared = CanvasSelection(elements: [Self.box.id]).pressed(label: nil, element: nil, at: outside, extending: false, in: document)
        #expect(cleared.selection.isEmpty && cleared.dragging == .nothing)
        let kept = CanvasSelection(elements: [Self.box.id]).pressed(label: nil, element: nil, at: outside, extending: true, in: document)
        #expect(kept.selection.elements == [Self.box.id] && kept.dragging == .nothing)
    }

    @Test func extendingTogglesAnElementAndMovesNothing() {
        let added = CanvasSelection(elements: [Self.box.id]).pressed(label: nil, element: Self.spare.id, at: inside, extending: true, in: document)
        #expect(added.selection.elements == [Self.box.id, Self.spare.id] && added.dragging == .nothing)
        let removed = added.selection.pressed(label: nil, element: Self.box.id, at: inside, extending: true, in: document)
        #expect(removed.selection.elements == [Self.spare.id])
    }

    @Test func pressingAnElementAlreadySelectedMovesTheWholeSelection() {
        let press = CanvasSelection(elements: [Self.box.id, Self.spare.id]).pressed(label: nil, element: Self.spare.id, at: inside, extending: false, in: document)
        #expect(press.selection.elements == [Self.box.id, Self.spare.id])
        #expect(press.dragging == .elements([Self.box.id, Self.spare.id]))
    }

    @Test func whatIsNoLongerThereIsNotSelected() {
        let gone = CanvasDocument(frames: [Self.two])
        #expect(CanvasSelection(frame: Self.one.id).live(in: gone).isEmpty)
        #expect(CanvasSelection(elements: [Self.box.id]).live(in: gone).isEmpty)
        #expect(CanvasSelection(frame: Self.two.id).live(in: gone).frame == Self.two.id)
    }

    @Test func aFrameIsPickedByItsNameAboveItInScreenSpace() {
        let viewport = CanvasViewport(zoom: 0.5, offset: CanvasPoint(x: 100, y: 200))
        func hit(_ x: Double, _ y: Double) -> CanvasFrameID? {
            CanvasHitTest.frameLabel(at: CanvasPoint(x: x, y: y), in: document, viewport: viewport) { _ in 60 }
        }
        #expect(hit(110, 190) == Self.one.id)
        #expect(hit(100, 180) == Self.one.id)
        #expect(hit(160, 199) == Self.one.id)
        #expect(hit(161, 190) == nil)
        #expect(hit(99, 190) == nil)
        #expect(hit(110, 179) == nil)
        #expect(hit(110, 200) == nil)
        #expect(hit(410, 190) == Self.two.id)
    }

    @Test func aFrameWithAVeryShortNameCanStillBePicked() {
        let hit = CanvasHitTest.frameLabel(at: CanvasPoint(x: 30, y: -5), in: document, viewport: CanvasViewport()) { _ in 0 }
        #expect(hit == Self.one.id)
    }

    @Test func theFrameDrawnLastWinsItsName() {
        let over = CanvasFrame(id: CanvasFrameID("over"), name: "Over", rect: CanvasRect(x: 0, y: 0, width: 10, height: 10))
        let hit = CanvasHitTest.frameLabel(
            at: CanvasPoint(x: 5, y: -5), in: CanvasDocument(frames: [Self.one, over]), viewport: CanvasViewport()
        ) { _ in 60 }
        #expect(hit == over.id)
    }
}
