import Testing
@testable import Core

@Suite("CanvasAlignment")
struct CanvasAlignmentTests {
    private let frameID = CanvasFrameID("f")

    private func shape(_ id: String, _ x: Double, _ y: Double, _ width: Double = 20, _ height: Double = 20) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), frameID: frameID, revision: 4,
            rect: CanvasRect(x: x, y: y, width: width, height: height), kind: .shape(CanvasShape(kind: .rectangle))
        )
    }

    private func document(_ elements: [CanvasElement]) -> CanvasDocument {
        CanvasDocument(
            frames: [CanvasFrame(id: frameID, name: "F", rect: CanvasRect(x: 500, y: 0, width: 200, height: 100))],
            elements: elements
        )
    }

    private func applied(_ operations: [CanvasOperation], to document: CanvasDocument) -> CanvasDocument {
        var session = CanvasDocumentSession(document: document)
        _ = session.apply(operations, by: .owner)
        return session.document
    }

    private func rect(_ id: String, in document: CanvasDocument) -> CanvasRect? {
        document.elements.first { $0.id == CanvasElementID(id) }?.rect
    }

    @Test func alignLeftUsesTheLeftmost() {
        let start = document([shape("a", 30, 0), shape("b", 10, 40), shape("c", 70, 80)])
        let ids = ["a", "b", "c"].map(CanvasElementID.init)
        let result = applied(CanvasAlignment.align(ids, to: .left, in: start), to: start)
        #expect(["a", "b", "c"].allSatisfy { rect($0, in: result)?.origin.x == 10 })
        #expect(rect("a", in: result)?.origin.y == 0)
    }

    @Test func alignRightAndCentreUseTheGroupBounds() {
        let start = document([shape("a", 0, 0, 20), shape("b", 80, 40, 40)])
        let ids = ["a", "b"].map(CanvasElementID.init)
        let right = applied(CanvasAlignment.align(ids, to: .right, in: start), to: start)
        let centre = applied(CanvasAlignment.align(ids, to: .centreX, in: start), to: start)
        #expect(rect("a", in: right)?.origin.x == 100)
        #expect(rect("b", in: right)?.origin.x == 80)
        #expect(rect("a", in: centre)?.origin.x == 50)
        #expect(rect("b", in: centre)?.origin.x == 40)
    }

    @Test func aSingleElementAlignsToItsFrame() {
        let start = document([shape("a", 30, 30, 20, 20)])
        let ids = [CanvasElementID("a")]
        let left = applied(CanvasAlignment.align(ids, to: .left, in: start), to: start)
        let right = applied(CanvasAlignment.align(ids, to: .right, in: start), to: start)
        let middle = applied(CanvasAlignment.align(ids, to: .middleY, in: start), to: start)
        let bottom = applied(CanvasAlignment.align(ids, to: .bottom, in: start), to: start)
        #expect(rect("a", in: left)?.origin.x == 0)
        #expect(rect("a", in: right)?.origin.x == 180)
        #expect(rect("a", in: middle)?.origin.y == 40)
        #expect(rect("a", in: bottom)?.origin.y == 80)
    }

    @Test func anElementAlreadyThereGetsNoOperation() {
        let start = document([shape("a", 0, 0), shape("b", 50, 0)])
        let operations = CanvasAlignment.align(["a", "b"].map(CanvasElementID.init), to: .left, in: start)
        #expect(operations.count == 1)
    }

    @Test func distributeNeedsThree() {
        let start = document([shape("a", 0, 0), shape("b", 30, 0)])
        let ids = ["a", "b"].map(CanvasElementID.init)
        #expect(CanvasAlignment.distribute(ids, axis: .horizontal, in: start).isEmpty)
        #expect(CanvasAlignment.distribute([], axis: .vertical, in: start).isEmpty)
    }

    @Test func distributeSpacesTheGapsEvenly() {
        let start = document([shape("a", 0, 0), shape("b", 20, 0), shape("c", 180, 0, 20)])
        let ids = ["a", "b", "c"].map(CanvasElementID.init)
        let result = applied(CanvasAlignment.distribute(ids, axis: .horizontal, in: start), to: start)
        #expect(rect("a", in: result)?.origin.x == 0)
        #expect(rect("b", in: result)?.origin.x == 90)
        #expect(rect("c", in: result)?.origin.x == 180)
    }
}
