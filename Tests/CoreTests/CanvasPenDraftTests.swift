import Foundation
import Testing
@testable import Core

@Suite("A pen stroke while it is drawn")
struct CanvasPenDraftTests {
    private let tolerance = 1.5

    private func draw(_ points: [CanvasPoint]) -> CanvasPenDraft {
        var draft = CanvasPenDraft()
        for point in points { draft.append(point, tolerance: tolerance) }
        return draft
    }

    private func committed(_ draft: CanvasPenDraft) -> [CanvasPoint]? {
        guard let element = draft.element(width: 6, colour: "#111827", tolerance: tolerance, in: CanvasDocument()),
              case .stroke(let stroke) = element.kind else { return nil }
        return stroke.points.map { CanvasPoint(x: $0.x + element.rect.origin.x, y: $0.y + element.rect.origin.y) }
    }

    @Test func theDraftNeverHoldsMoreThanTheInputLimit() {
        var draft = CanvasPenDraft()
        for point in CanvasDeviation.zigzag(12_000, amplitude: 16) {
            draft.append(point, tolerance: tolerance)
            #expect(draft.points.count <= CanvasStrokeBuilder.inputLimit)
        }
        #expect(draft.wasCoarsened)
    }

    @Test func theCommittedLineStaysWithinTheToleranceOfWhatWasShown() throws {
        let draft = draw(CanvasDeviation.cursive(9_000))
        let result = try #require(committed(draft))
        #expect(CanvasDeviation.max(of: draft.points, from: result) <= tolerance + 1e-9)
        #expect(result.count <= draft.points.count)
    }

    @Test func aShortStrokeIsNeverCoarsened() {
        let draft = draw(CanvasDeviation.cursive(500))
        #expect(!draft.wasCoarsened)
    }

    @Test func aPlainPenStrokeIsOnlySmoothedAtTheToleranceWhenItFits() throws {
        let raw = CanvasDeviation.cursive(3_000)
        let result = try #require(committed(draw(raw)))
        #expect(CanvasDeviation.max(of: raw, from: result) <= tolerance + 1e-9)
    }

    @Test func cutsDuringDrawingAddUpAndTheSumIsMeasuredNotAssumed() throws {
        let raw = CanvasDeviation.cursive(9_000)
        let draft = draw(raw)
        let result = try #require(committed(draft))
        let measured = CanvasDeviation.max(of: raw, from: result)
        print("MEASURE cursive of 9000 points, cuts at 4096: draft \(draft.points.count) points, committed \(result.count), deviation from the raw points \(measured)")
        #expect(measured < 10 * tolerance)
    }

    @Test func cutsThroughANoisyZigzagAreMeasuredToo() throws {
        let raw = CanvasDeviation.zigzag(9_000, amplitude: 16)
        let draft = draw(raw)
        let result = try #require(committed(draft))
        let measured = CanvasDeviation.max(of: raw, from: result)
        print("MEASURE zigzag of 9000 points, amplitude 16: draft \(draft.points.count) points, committed \(result.count), coarsened \(draft.wasCoarsened), deviation from the raw points \(measured)")
        #expect(draft.wasCoarsened)
        #expect(measured <= 16)
    }

    @Test(arguments: [
        ("cursive", CanvasDeviation.cursive(9_000)),
        ("zigzag", CanvasDeviation.zigzag(9_000, amplitude: 16)),
        ("looped cursive", CanvasDeviation.loopedCursive(20_000)),
    ])
    func everyCutIsCountedInTheBound(name: String, raw: [CanvasPoint]) throws {
        let draft = draw(raw)
        let result = try #require(committed(draft))
        let measured = CanvasDeviation.max(of: raw, from: result)
        print("MEASURE \(name) of \(raw.count) points through the pen: draft \(draft.points.count), committed \(result.count), coarsened \(draft.wasCoarsened), bound \(draft.deviationBound + tolerance), deviation \(measured)")
        #expect(draft.deviationBound >= tolerance)
        #expect(measured <= draft.deviationBound + tolerance + 1e-6)
    }

    @Test func aStrokeThatIsNeverCutHasNoBoundOfItsOwn() {
        #expect(draw(CanvasDeviation.cursive(4_096)).deviationBound == 0)
    }

    private func fewestAfterACut(_ raw: [CanvasPoint]) -> Int {
        var draft = CanvasPenDraft()
        var fewest = Int.max
        for point in raw {
            let before = draft.points.count
            draft.append(point, tolerance: tolerance)
            if draft.points.count < before { fewest = min(fewest, draft.points.count) }
        }
        return fewest
    }

    @Test func aCutCanLeaveAStrokeOfLoopsWithOnlyAFewPointsAndTheBoundStillHolds() {
        let shapes: [(fewest: Int, raw: [CanvasPoint])] = [
            (3, CanvasDeviation.loopedCursive(20_000)),
            (2, (0..<20_000).map { CanvasPoint(x: Double($0) * 0.01 + 200 * sin(Double($0) / 2.3), y: 200 * cos(Double($0) / 2.3)) }),
        ]
        for shape in shapes {
            let draft = draw(shape.raw)
            let measured = CanvasDeviation.max(of: shape.raw, from: draft.points)
            print("MEASURE loops through the pen: fewest after a cut \(fewestAfterACut(shape.raw)), draft \(draft.points.count), bound \(draft.deviationBound), deviation \(measured)")
            #expect(fewestAfterACut(shape.raw) == shape.fewest)
            #expect(draft.wasCoarsened)
            #expect(measured <= draft.deviationBound + 1e-6)
        }
    }

    @Test func aCutThroughAnEvenZigzagKeepsItsShape() {
        let raw = (0..<20_000).map { CanvasPoint(x: Double($0), y: $0 % 2 == 0 ? 0 : 16) }
        #expect(fewestAfterACut(raw) == 1_025)
    }
}
