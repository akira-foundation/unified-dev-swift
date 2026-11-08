import Testing
@testable import Core

@Suite("CanvasHitTest on lines, outlines and strokes")
struct CanvasStrokeHitTestTests {
    private func shape(
        _ id: String, _ kind: CanvasShape.Kind, _ rect: CanvasRect, fill: String? = nil, stroke: String? = "#000000", width: Double = 4,
        rotation: Double = 0
    ) -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), rect: rect,
            style: CanvasStyle(fill: fill, stroke: stroke, strokeWidth: width, rotation: rotation), kind: .shape(CanvasShape(kind: kind))
        )
    }

    private func hit(_ x: Double, _ y: Double, in elements: [CanvasElement], tolerance: Double = 0) -> CanvasElementID? {
        CanvasHitTest.element(at: CanvasPoint(x: x, y: y), in: CanvasDocument(elements: elements), tolerance: tolerance)
    }

    @Test func anUnfilledRectangleIsHitOnItsOutlineAndNotInside() {
        let frame = shape("r", .rectangle, CanvasRect(x: 0, y: 0, width: 200, height: 100))
        #expect(hit(0, 50, in: [frame]) == frame.id)
        #expect(hit(100, 100, in: [frame]) == frame.id)
        #expect(hit(100, 50, in: [frame]) == nil)
    }

    @Test func anUnfilledShapeDoesNotStealAClickFromWhatLiesUnderIt() {
        let under = shape("under", .rectangle, CanvasRect(x: 40, y: 20, width: 40, height: 40), fill: "#FF0000", stroke: nil, width: 0)
        let ring = shape("ring", .ellipse, CanvasRect(x: 0, y: 0, width: 200, height: 100))
        #expect(hit(60, 40, in: [under, ring]) == under.id)
    }

    @Test func aFilledShapeIsHitInside() {
        let box = shape("f", .rectangle, CanvasRect(x: 0, y: 0, width: 200, height: 100), fill: "#00FF00")
        #expect(hit(100, 50, in: [box]) == box.id)
    }

    @Test func aFullyTransparentFillCountsAsUnfilled() {
        let box = shape("t", .rectangle, CanvasRect(x: 0, y: 0, width: 200, height: 100), fill: "#00FF0000")
        #expect(hit(100, 50, in: [box]) == nil)
    }

    @Test func anEllipseIsHitOnItsOutline() {
        let ring = shape("e", .ellipse, CanvasRect(x: 0, y: 0, width: 200, height: 100))
        #expect(hit(0, 50, in: [ring]) == ring.id)
        #expect(hit(100, 0, in: [ring]) == ring.id)
        #expect(hit(100, 50, in: [ring]) == nil)
        #expect(hit(2, 2, in: [ring]) == nil)
    }

    @Test func aLineIsHitAlongItsLineNotItsBox() {
        let line = shape("l", .line, CanvasRect(x: 0, y: 0, width: 200, height: 40))
        #expect(hit(100, 20, in: [line]) == line.id)
        #expect(hit(100, 5, in: [line]) == nil)
        #expect(hit(100, 35, in: [line]) == nil)
    }

    @Test func aRotatedLineIsHitAlongTheRotatedLine() {
        let line = shape("l", .line, CanvasRect(x: 0, y: 80, width: 200, height: 40), rotation: 90)
        #expect(hit(100, 20, in: [line]) == line.id)
        #expect(hit(20, 100, in: [line]) == nil)
    }

    @Test func anArrowHeadIsPartOfTheArrow() {
        let arrow = shape("a", .arrow, CanvasRect(x: 0, y: 0, width: 200, height: 40))
        #expect(hit(188, 14, in: [arrow]) == arrow.id)
        #expect(hit(100, 10, in: [arrow]) == nil)
    }

    @Test func toleranceWidensWhatCountsAsOnTheLine() {
        let line = shape("l", .line, CanvasRect(x: 0, y: 0, width: 200, height: 40), width: 2)
        #expect(hit(100, 27, in: [line]) == nil)
        #expect(hit(100, 27, in: [line], tolerance: 8) == line.id)
    }

    @Test func aStrokeIsHitOnItsPathWithinHalfItsWidth() {
        let stroke = CanvasElement(
            id: CanvasElementID("s"), rect: CanvasRect(x: 100, y: 100, width: 120, height: 120),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 10, y: 10), CanvasPoint(x: 110, y: 10), CanvasPoint(x: 110, y: 110)], width: 10, colour: "#000000"))
        )
        #expect(hit(160, 110, in: [stroke]) == stroke.id)
        #expect(hit(160, 114, in: [stroke]) == stroke.id)
        #expect(hit(160, 130, in: [stroke]) == nil)
        #expect(hit(120, 200, in: [stroke]) == nil)
    }

    @Test func aDotStrokeIsHitAroundItsPoint() {
        let dot = CanvasElement(
            id: CanvasElementID("d"), rect: CanvasRect(x: 50, y: 50, width: 10, height: 10),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 5, y: 5)], width: 10, colour: "#000000"))
        )
        #expect(hit(55, 55, in: [dot]) == dot.id)
        #expect(hit(70, 70, in: [dot]) == nil)
    }

    @Test func aStrokeInAFrameIsHitInFrameCoordinates() {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 0, width: 500, height: 500))
        let stroke = CanvasElement(
            id: CanvasElementID("s"), frameID: frame.id, rect: CanvasRect(x: 10, y: 10, width: 104, height: 4),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 2, y: 2), CanvasPoint(x: 102, y: 2)], width: 4, colour: "#000000"))
        )
        let document = CanvasDocument(frames: [frame], elements: [stroke])
        #expect(CanvasHitTest.element(at: CanvasPoint(x: 1_062, y: 12), in: document) == stroke.id)
        #expect(CanvasHitTest.element(at: CanvasPoint(x: 62, y: 12), in: document) == nil)
    }

    @Test func aRotatedLineIsHitWhereTheRotationSendsItNotWhereItsMirrorWould() {
        let line = shape("l", .line, CanvasRect(x: 0, y: 0, width: 200, height: 24), rotation: 30)
        #expect(hit(186.6, 62, in: [line]) == line.id)
        #expect(hit(13.4, -38, in: [line]) == line.id)
        #expect(hit(186.6, -38, in: [line]) == nil)
        #expect(hit(13.4, 62, in: [line]) == nil)
    }

    @Test func aStrokeReachesHalfItsWidthAndNoFurther() {
        let stroke = CanvasElement(
            id: CanvasElementID("s"), rect: CanvasRect(x: 0, y: 0, width: 120, height: 20),
            kind: .stroke(CanvasStroke(points: [CanvasPoint(x: 10, y: 10), CanvasPoint(x: 110, y: 10)], width: 10, colour: "#000000"))
        )
        #expect(hit(60, 14, in: [stroke]) == stroke.id)
        #expect(hit(60, 17, in: [stroke]) == nil)
        #expect(hit(60, 17, in: [stroke], tolerance: 3) == stroke.id)
    }

    @Test func aShapeOutlineReachesHalfItsWidthAndNoFurther() {
        let line = shape("l", .line, CanvasRect(x: 0, y: 0, width: 200, height: 40), width: 6)
        #expect(hit(100, 22, in: [line]) == line.id)
        #expect(hit(100, 25, in: [line]) == nil)
        let ring = shape("r", .rectangle, CanvasRect(x: 0, y: 0, width: 200, height: 100), width: 6)
        #expect(hit(100, 2, in: [ring]) == ring.id)
        #expect(hit(100, 5, in: [ring]) == nil)
    }
}
