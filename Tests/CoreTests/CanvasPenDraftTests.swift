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

    private struct Scribble {
        var draft = CanvasPenDraft()
        var taken: [CanvasPoint] = []
        var cuts = 0
        var fewest = Int.max
    }

    private func scribble(_ raw: [CanvasPoint]) -> Scribble {
        var run = Scribble()
        for point in raw {
            let before = run.draft.points.count
            run.draft.append(point, tolerance: tolerance)
            if run.draft.hasStopped { break }
            run.taken.append(point)
            guard run.draft.points.count < before else { continue }
            run.cuts += 1
            run.fewest = min(run.fewest, run.draft.points.count)
        }
        return run
    }

    private static func loops(radius: Double, count: Int = 20_000) -> [CanvasPoint] {
        (0..<count).map { CanvasPoint(x: Double($0) * 0.01 + radius * sin(Double($0) / 2.3), y: radius * cos(Double($0) / 2.3)) }
    }

    @Test(arguments: [
        (radius: 30.0, stops: true, cuts: 1, fewest: 1_701),
        (radius: 200.0, stops: true, cuts: 0, fewest: Int.max),
        (radius: 5.0, stops: true, cuts: 5, fewest: 1_468),
    ])
    func aStrokeOfLoopsMeetsTheCeiling(radius: Double, stops: Bool, cuts: Int, fewest: Int) throws {
        let run = scribble(Self.loops(radius: radius))
        let result = try #require(committed(run.draft))
        let bound = Double(run.cuts) * CanvasPenDraft.toleranceCeiling * tolerance + tolerance
        let measured = CanvasDeviation.max(of: run.taken, from: result)
        print("MEASURE loops of radius \(radius): stopped \(run.draft.hasStopped) after \(run.taken.count) samples, cuts \(run.cuts), fewest after a cut \(run.fewest), draft \(run.draft.points.count), committed \(result.count), deviation \(measured), bound \(bound)")
        #expect(run.draft.hasStopped == stops)
        #expect(run.cuts == cuts)
        #expect(run.fewest == fewest)
        #expect(run.draft.points.count <= CanvasStrokeBuilder.inputLimit)
        #expect(measured <= bound + 1e-6)
    }

    @Test func releasingAStoppedDraftDoesNotCollapseIt() throws {
        let draft = scribble(Self.loops(radius: 30)).draft
        let result = try #require(committed(draft))
        #expect(draft.hasStopped)
        #expect(CanvasDeviation.max(of: draft.points, from: result) <= tolerance + 1e-6)
        #expect(result.count > CanvasStrokeBuilder.inputLimit / 2)
    }

    @Test func aSmallLoopStopsWithTheDraftIntactAtTheLimit() throws {
        let run = scribble(Self.loops(radius: 2))
        #expect(run.draft.hasStopped)
        #expect(run.draft.points.count == CanvasStrokeBuilder.inputLimit)
        #expect(run.draft.points.last == run.taken.last)
        #expect(run.fewest >= CanvasPenDraft.floor)
    }

    @Test func aPlainCutLeavingFewPointsDoesNotStop() {
        let straight = (0...CanvasStrokeBuilder.inputLimit).map { CanvasPoint(x: Double($0), y: 0) }
        let draft = draw(straight)
        #expect(!draft.hasStopped && !draft.wasCoarsened)
        #expect(draft.points.count < CanvasPenDraft.floor)
    }

    @Test func samplingPastTheStopChangesNothing() {
        var draft = scribble(Self.loops(radius: 30)).draft
        let stopped = draft
        draft.append(CanvasPoint(x: 9_999, y: 9_999), tolerance: tolerance)
        draft.append(CanvasPoint(x: 9_999, y: 1), tolerance: tolerance * 4)
        #expect(stopped.hasStopped)
        #expect(draft == stopped)
    }

    @Test func aCutThatReachesItsTargetDoesNotStop() {
        let draft = draw(CanvasDeviation.cursive(9_000))
        #expect(!draft.hasStopped)
    }

    @Test func aCutThatLandsExactlyOnTheTargetDoesNotStop() throws {
        let target = CanvasStrokeBuilder.inputLimit / 2
        let strokes = (target - 16...target + 16).map { corners in
            (0...CanvasStrokeBuilder.inputLimit).map { index in
                CanvasPoint(x: Double(index), y: index < corners && index % 2 == 1 ? 16 : 0)
            }
        }
        let exact = try #require(strokes.first {
            CanvasStrokeBuilder.reduction(of: $0, tolerance: tolerance, limit: CanvasStrokeBuilder.inputLimit).points.count == target
        })
        let draft = draw(exact)
        #expect(!draft.hasStopped && !draft.wasCoarsened)
        #expect(draft.points.count == target)
    }

    @Test func aFourTimesTheToleranceCutIsAllowedAndAnEightTimesToo() {
        var draft = CanvasPenDraft()
        for point in (0..<4_097).map({ CanvasPoint(x: Double($0), y: $0 % 2 == 0 ? 0 : 16) }) {
            draft.append(point, tolerance: tolerance)
        }
        #expect(!draft.hasStopped && draft.wasCoarsened && draft.points.count <= 2_048)
    }

    @Test func aStopIsSaidWhileDrawingAndNothingIsSaidBefore() throws {
        #expect(CanvasStrokeNotice.whileDrawing(draw(CanvasDeviation.cursive(500))) == nil)
        let notice = try #require(CanvasStrokeNotice.whileDrawing(scribble(Self.loops(radius: 30)).draft))
        let said = ([notice.title] + notice.lines).joined(separator: " ")
        #expect(said.contains("reached its limit") && said.contains("Release") && said.contains("new"))
        #expect(!said.contains("exact") && !said.contains("kept"))
    }

    @Test func aRefusedDraftStaysUntilTheNextStrokeStarts() {
        var draft = draw([CanvasPoint(x: 0, y: 0), CanvasPoint(x: 1, y: 1)])
        draft.refused()
        #expect(draft.isRefused && draft.points.count == 2)
        draft.append(CanvasPoint(x: 9, y: 9), tolerance: tolerance)
        #expect(!draft.isRefused && draft.points == [CanvasPoint(x: 9, y: 9)])
    }

    @Test func aRefusedDraftGoesWhenItsNoticeIsDismissed() {
        var draft = draw([CanvasPoint(x: 0, y: 0), CanvasPoint(x: 1, y: 1)])
        draft.noticeDismissed()
        #expect(draft.points.count == 2)
        draft.refused()
        draft.noticeDismissed()
        #expect(draft.isEmpty && !draft.isRefused)
    }
}
