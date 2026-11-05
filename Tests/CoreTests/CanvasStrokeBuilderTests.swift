import Testing
@testable import Core

@Suite("CanvasStrokeBuilder")
struct CanvasStrokeBuilderTests {
    private func point(_ x: Double, _ y: Double) -> CanvasPoint { CanvasPoint(x: x, y: y) }

    @Test func simplifyKeepsEndsAndDropsCollinear() {
        let line = (0...10).map { point(Double($0) * 10, Double($0) * 5) }
        let simplified = CanvasStrokeBuilder.simplified(line, tolerance: 0.5)
        #expect(simplified == [point(0, 0), point(100, 50)])
    }

    @Test func simplifyKeepsACorner() {
        let corner = [point(0, 0), point(50, 0), point(100, 0), point(100, 50), point(100, 100)]
        let simplified = CanvasStrokeBuilder.simplified(corner, tolerance: 1)
        #expect(simplified == [point(0, 0), point(100, 0), point(100, 100)])
    }

    @Test func simplifyTerminatesOnDuplicatePoints() {
        let same = Array(repeating: point(5, 5), count: 1_000)
        #expect(CanvasStrokeBuilder.simplified(same, tolerance: 1) == [point(5, 5)])
        let doubled = [point(0, 0), point(0, 0), point(10, 10), point(10, 10), point(10, 10)]
        #expect(CanvasStrokeBuilder.simplified(doubled, tolerance: 0) == [point(0, 0), point(10, 10)])
    }

    @Test func simplifyOfNothingIsNothing() {
        #expect(CanvasStrokeBuilder.simplified([], tolerance: 1).isEmpty)
    }

    @Test func simplifyBoundsItsInputAndKeepsBothEnds() {
        let many = (0..<200_000).map { point(Double($0), Double($0 % 7) * 40) }
        let simplified = CanvasStrokeBuilder.simplified(many, tolerance: 1)
        #expect(simplified.first == many.first)
        #expect(simplified.last == many.last)
        #expect(simplified.count <= CanvasStrokeBuilder.inputLimit)
    }

    @Test func onePointStrokeHasABound() {
        let stroke = CanvasStroke(points: [point(30, 40)], width: 10, colour: "#000000")
        let bounds = CanvasStrokeBuilder.bounds(stroke)
        #expect(bounds == CanvasRect(x: 25, y: 35, width: 10, height: 10))
    }

    @Test func aStrokeWithNoPointsStillHasASize() {
        let bounds = CanvasStrokeBuilder.bounds(CanvasStroke(points: [], width: 0, colour: "#000000"))
        #expect(bounds.size.width > 0 && bounds.size.height > 0)
    }

    @Test func boundsReachHalfAWidthPastThePoints() {
        let stroke = CanvasStroke(points: [point(0, 0), point(100, 20)], width: 6, colour: "#000000")
        #expect(CanvasStrokeBuilder.bounds(stroke) == CanvasRect(x: -3, y: -3, width: 106, height: 26))
    }

    @Test func aDrawnStrokeStoresPointsRelativeToItsRect() throws {
        let frame = CanvasFrame(id: CanvasFrameID("f"), name: "F", rect: CanvasRect(x: 1_000, y: 500, width: 1_080, height: 1_080))
        let document = CanvasDocument(frames: [frame])
        let element = try #require(CanvasStrokeBuilder.element(
            drawing: [point(1_100, 600), point(1_200, 700)], width: 4, colour: "#111111", tolerance: 0, in: document
        ))
        guard case .stroke(let stroke) = element.kind else { Issue.record("not a stroke"); return }
        #expect(element.frameID == frame.id)
        #expect(element.rect == CanvasRect(x: 98, y: 98, width: 104, height: 104))
        #expect(stroke.points == [point(2, 2), point(102, 102)])
    }

    @Test func aStrokeOutsideEveryFrameIsLooseAndAbsolute() throws {
        let element = try #require(CanvasStrokeBuilder.element(
            drawing: [point(10, 10), point(20, 10)], width: 2, colour: "#111111", tolerance: 0, in: CanvasDocument()
        ))
        #expect(element.frameID == nil)
        #expect(element.rect == CanvasRect(x: 9, y: 9, width: 12, height: 2))
    }

    @Test func noPointsDrawNoElement() {
        #expect(CanvasStrokeBuilder.element(drawing: [], width: 2, colour: "#000000", tolerance: 1, in: CanvasDocument()) == nil)
    }

    @Test func resizingScalesThePointsInsideThePadding() {
        let stroke = CanvasStroke(points: [point(2, 2), point(102, 52)], width: 4, colour: "#000000")
        let resized = CanvasStrokeBuilder.resized(stroke, from: CanvasSize(width: 104, height: 54), to: CanvasSize(width: 204, height: 104))
        #expect(resized.points == [point(2, 2), point(202, 102)])
        #expect(resized.width == 4)
    }

    @Test func resizingADotCentresIt() {
        let dot = CanvasStroke(points: [point(5, 5)], width: 10, colour: "#000000")
        let resized = CanvasStrokeBuilder.resized(dot, from: CanvasSize(width: 10, height: 10), to: CanvasSize(width: 40, height: 20))
        #expect(resized.points == [point(20, 10)])
    }
}
