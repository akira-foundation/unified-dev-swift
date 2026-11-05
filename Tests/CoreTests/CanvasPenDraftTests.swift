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
}
