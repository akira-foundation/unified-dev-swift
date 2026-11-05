import Foundation
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

    private var twoFrames: CanvasDocument {
        CanvasDocument(frames: [
            CanvasFrame(id: CanvasFrameID("a"), name: "A", rect: CanvasRect(x: 0, y: 0, width: 500, height: 500)),
            CanvasFrame(id: CanvasFrameID("b"), name: "B", rect: CanvasRect(x: 600, y: 0, width: 500, height: 500)),
        ])
    }

    private func frameOf(_ points: [CanvasPoint]) -> CanvasFrameID?? {
        CanvasStrokeBuilder.element(drawing: points, width: 2, colour: "#000000", tolerance: 0, in: twoFrames).map(\.frameID)
    }

    @Test func aStrokeStartingJustOutsideBelongsToTheFrameItMostlyCrosses() {
        let points = [point(-1, 100)] + (0..<30).map { point(10 + Double($0) * 10, 100) }
        #expect(frameOf(points) == .some(CanvasFrameID("a")))
    }

    @Test func aStrokeStartingInOneFrameBelongsToTheOneHoldingMostPoints() {
        let points = [point(100, 100)] + (0..<5).map { point(650 + Double($0) * 10, 100) }
        #expect(frameOf(points) == .some(CanvasFrameID("b")))
    }

    @Test func aStrokeEndingInAFrameBelongsToItWhenMostPointsAreThere() {
        let points = [point(-50, 100), point(-40, 100), point(10, 100), point(20, 100), point(30, 100)]
        #expect(frameOf(points) == .some(CanvasFrameID("a")))
    }

    @Test func theLastPointDoesNotDecideTheFrame() {
        let inA = (0..<6).map { point(100 + Double($0) * 10, 100) }
        #expect(frameOf(inA + [point(650, 100)]) == .some(CanvasFrameID("a")))
        #expect(frameOf(inA + [point(560, 100)]) == .some(CanvasFrameID("a")))
    }

    @Test func aStrokeInNoFrameBelongsToNone() {
        #expect(frameOf([point(520, 100), point(540, 100)]) == .some(nil))
    }

    @Test func reframingAfterAWidthChangeKeepsThePointsWhereTheyAre() {
        let element = CanvasElement(
            rect: CanvasRect(x: 50, y: 60, width: 14, height: 14),
            kind: .stroke(CanvasStroke(points: [point(2, 2), point(12, 12)], width: 4, colour: "#000000"))
        )
        let wider = CanvasStroke(points: [point(2, 2), point(12, 12)], width: 10, colour: "#000000")
        let patch = CanvasStrokeBuilder.reframed(element, with: wider)
        #expect(patch.rect == CanvasRect(x: 47, y: 57, width: 20, height: 20))
        #expect(patch.kind == .stroke(CanvasStroke(points: [point(5, 5), point(15, 15)], width: 10, colour: "#000000")))
    }

    @Test func appendingNeverLetsAStrokePassTheLimit() {
        var points: [CanvasPoint] = []
        for index in 0..<(CanvasStrokeBuilder.maximumPoints * 2 + 5) {
            points = CanvasStrokeBuilder.appending(point(Double(index), Double((index * 37) % 211)), to: points, tolerance: 0.5)
            #expect(points.count < CanvasStrokeBuilder.maximumPoints)
        }
        #expect(points.last == point(Double(CanvasStrokeBuilder.maximumPoints * 2 + 4), Double(((CanvasStrokeBuilder.maximumPoints * 2 + 4) * 37) % 211)))
    }

    @Test func resizingScalesFromTheRealBoxOfThePoints() {
        let thick = CanvasStroke(points: [point(3, 3), point(37, 37)], width: 30, colour: "#000000")
        let wide = CanvasStrokeBuilder.resized(thick, from: CanvasSize(width: 40, height: 40), to: CanvasSize(width: 80, height: 80))
        #expect(wide.points == [point(15, 15), point(65, 65)])
        let fat = CanvasStroke(points: [point(3, 3), point(37, 37)], width: 64, colour: "#000000")
        let squeezed = CanvasStrokeBuilder.resized(fat, from: CanvasSize(width: 40, height: 40), to: CanvasSize(width: 80, height: 80))
        #expect(squeezed.points == [point(32, 32), point(48, 48)])
    }

    @Test func aSharpSpikeSurvivesAStrokeFarPastTheLimit() {
        var line = (0..<20_000).map { point(Double($0) * 0.1, 0) }
        line[10_001] = point(1_000.1, 50)
        let simplified = CanvasStrokeBuilder.simplified(line, tolerance: 0.5)
        #expect(simplified.contains(point(1_000.1, 50)))
        #expect(simplified.first == line.first && simplified.last == line.last)
        #expect(simplified.count < 10)
    }

    @Test func aCornerSurvivesAStrokeFarPastTheLimit() {
        let leg = 30_000
        let along = (0..<leg).map { point(Double($0) * 0.01, 0) }
        let down = (1...leg).map { point(Double(leg - 1) * 0.01, Double($0) * 0.01) }
        let corner = point(Double(leg - 1) * 0.01, 0)
        let simplified = CanvasStrokeBuilder.simplified(along + down, tolerance: 0.5)
        #expect(simplified.count < 10)
        #expect(simplified.contains { hypot($0.x - corner.x, $0.y - corner.y) <= 0.5 })
    }

    @Test func aLongStrokeIsReducedOnReleaseOnlyPastTheInputLimit() {
        #expect(!CanvasStrokeBuilder.isReducedOnRelease(rawCount: CanvasStrokeBuilder.inputLimit))
        #expect(CanvasStrokeBuilder.isReducedOnRelease(rawCount: CanvasStrokeBuilder.inputLimit + 1))
    }
}
