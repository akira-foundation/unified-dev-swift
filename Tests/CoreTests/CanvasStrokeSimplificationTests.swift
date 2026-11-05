import Foundation
import Testing
@testable import Core

@Suite("Simplifying a long stroke")
struct CanvasStrokeSimplificationTests {
    private func point(_ x: Double, _ y: Double) -> CanvasPoint { CanvasPoint(x: x, y: y) }

    @Test func aNoisyZigzagStaysWithinTheToleranceItWasReducedWith() {
        let zigzag = (0..<4_097).map { point(Double($0), $0 % 2 == 0 ? 0 : 16) }
        let reduction = CanvasStrokeBuilder.reduction(of: zigzag, tolerance: 1.5, limit: 2_048)
        #expect(reduction.points.count <= 2_048)
        #expect(reduction.coarsened && reduction.tolerance > 1.5)
        #expect(CanvasDeviation.max(of: zigzag, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aCursiveStaysWithinTheToleranceItWasReducedWith() {
        let cursive = CanvasDeviation.cursive(4_000)
        let reduction = CanvasStrokeBuilder.reduction(of: cursive, tolerance: 0.05, limit: 1_000)
        #expect(reduction.points.count <= 1_000)
        #expect(CanvasDeviation.max(of: cursive, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aSpikeSpacedAboveTheToleranceSurvives() {
        var line = (0..<4_000).map { point(Double($0), 0) }
        line[2_001] = point(2_001, 50)
        let reduction = CanvasStrokeBuilder.reduction(of: line, tolerance: 0.5, limit: CanvasStrokeBuilder.inputLimit)
        #expect(reduction.points.contains(point(2_001, 50)))
        #expect(reduction.points.first == line.first && reduction.points.last == line.last)
        #expect(CanvasDeviation.max(of: line, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aCornerSpacedAboveTheToleranceIsKeptExactly() {
        let leg = 2_000
        let along = (0..<leg).map { point(Double($0) * 2, 0) }
        let down = (1...leg).map { point(Double(leg - 1) * 2, Double($0) * 2) }
        let corner = point(Double(leg - 1) * 2, 0)
        let simplified = CanvasStrokeBuilder.simplified(along + down, tolerance: 0.5)
        #expect(simplified == [along[0], corner, down[leg - 1]])
    }

    @Test func aStrokeThatFitsIsNotCoarsened() {
        let wave = CanvasDeviation.zigzag(3_000, amplitude: 16)
        let reduction = CanvasStrokeBuilder.reduction(of: wave, tolerance: 1.5, limit: CanvasStrokeBuilder.inputLimit)
        #expect(!reduction.coarsened && reduction.tolerance == 1.5)
        #expect(CanvasDeviation.max(of: wave, from: reduction.points) <= 1.5 + 1e-9)
    }

    @Test func duplicatesAloneAreNotACoarsening() {
        let same = Array(repeating: point(5, 5), count: 20_000) + [point(9, 9)]
        let reduction = CanvasStrokeBuilder.reduction(of: same, tolerance: 1.5, limit: CanvasStrokeBuilder.inputLimit)
        #expect(!reduction.coarsened)
        #expect(reduction.points == [point(5, 5), point(9, 9)])
    }

    @Test func aLimitOfTwoLeavesTheEnds() {
        let cursive = CanvasDeviation.cursive(500)
        let reduction = CanvasStrokeBuilder.reduction(of: cursive, tolerance: 0.1, limit: 2)
        #expect(reduction.points == [cursive[0], cursive[499]])
    }

    @Test(arguments: [3, 5, 7, 101])
    func equalPeaksSplitAtTheMiddleOne(peaks: Int) {
        let row = (0...(peaks + 1)).map { point(Double($0), $0 == 0 || $0 == peaks + 1 ? 0 : 1_000) }
        let reduction = CanvasStrokeBuilder.reduction(of: row, tolerance: 999, limit: CanvasStrokeBuilder.inputLimit)
        #expect(reduction.points == [row[0], row[(peaks + 1) / 2], row[peaks + 1]])
    }

    @Test func aSawtoothAtTheBoundFitsAndStaysWithinWhatItReports() {
        let sawtooth = (0..<4_097).map { point(Double($0), Double($0 % 7) * 40) }
        let reduction = CanvasStrokeBuilder.reduction(of: sawtooth, tolerance: 1, limit: 2_048)
        #expect(reduction.points.count <= 2_048)
        #expect(CanvasDeviation.max(of: sawtooth, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aPointIsMeasuredAgainstItsOwnSegmentAndNotTheNearestOne() {
        let raw = [point(0, 0), point(9.9, 8), point(10, 0), point(10, 10)]
        let measured = CanvasDeviation.max(of: raw, from: [point(0, 0), point(10, 0), point(10, 10)])
        #expect(abs(measured - 8) < 1e-9)
    }

    @Test func aPolylineThatIsNotPickedFromThePointsMeasuresAsInfinite() {
        let raw = [point(0, 0), point(5, 1), point(10, 0)]
        #expect(CanvasDeviation.max(of: raw, from: [point(0, 0), point(6, 6), point(10, 0)]) == .infinity)
        #expect(CanvasDeviation.max(of: raw, from: [point(1, 1), point(10, 0)]) == .infinity)
    }

    @Test func aLoopedCursiveStaysWithinWhatItReportsAgainstItsOwnSegments() {
        let looped = CanvasDeviation.loopedCursive(4_000)
        let reduction = CanvasStrokeBuilder.reduction(of: looped, tolerance: 1.5, limit: 1_000)
        #expect(reduction.points.count <= 1_000)
        #expect(CanvasDeviation.max(of: looped, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aStrokeAtTheInputBoundIsReducedInOnePass() {
        let line = (0..<CanvasStrokeBuilder.reductionInputLimit).map { point(Double($0), 0) }
        let reduction = CanvasStrokeBuilder.reduction(of: line, tolerance: 1, limit: CanvasStrokeBuilder.inputLimit)
        #expect(reduction.points == [line[0], line[line.count - 1]])
        #expect(reduction.tolerance == 1)
    }

    @Test func oneLongerComesBackUnreduced() {
        let line = (0...CanvasStrokeBuilder.reductionInputLimit).map { point(Double($0), 0) }
        let reduction = CanvasStrokeBuilder.reduction(of: line, tolerance: 1, limit: 2)
        #expect(reduction == CanvasReduction(points: line, tolerance: 1, coarsened: false))
    }

    @Test func aHardStrokePastTheBoundDoesNoPassAtAll() {
        let spiral = (0..<30_000).map { index -> CanvasPoint in
            let turn = Double(index) / 3
            let radius = Double(index) * 0.01
            return point(radius * cos(turn), radius * sin(turn))
        }
        let reduction = CanvasStrokeBuilder.reduction(of: spiral, tolerance: 1.5, limit: 2)
        #expect(reduction.points == spiral && !reduction.coarsened)
    }

    @Test func aStrokePastTheBoundAndOverTheStrokeLimitIsRefusedVisibly() throws {
        let many = (0...CanvasStrokeBuilder.maximumPoints).map { point(Double($0), Double($0 % 2)) }
        let element = try #require(CanvasStrokeBuilder.element(drawing: many, width: 2, colour: "#000000", tolerance: 1, in: CanvasDocument()))
        var session = CanvasDocumentSession(document: CanvasDocument())
        guard case .invalid(let reason) = session.apply([.addElement(element)], by: .owner) else {
            Issue.record("expected a refusal")
            return
        }
        #expect(reason.contains("\(CanvasStrokeBuilder.maximumPoints)"))
    }

    @Test func theCeilingStopsTheDoublingAndSaysHowFarItGot() {
        let spike = [point(0, 0), point(5, 10), point(10, 0)]
        let under = CanvasStrokeBuilder.reduction(of: spike, tolerance: 1.5, limit: 2, ceiling: 11.9)
        #expect(under.points == spike && under.tolerance == 6 && under.coarsened)
        let at = CanvasStrokeBuilder.reduction(of: spike, tolerance: 1.5, limit: 2, ceiling: 12)
        #expect(at.points == [point(0, 0), point(10, 0)] && at.tolerance == 12)
    }

    @Test func theDoublingHasNoCeilingUnlessOneIsAskedFor() {
        let spike = [point(0, 0), point(5, 10_000), point(10, 0)]
        let reduction = CanvasStrokeBuilder.reduction(of: spike, tolerance: 1.5, limit: 2)
        #expect(reduction.points.count == 2)
    }

    @Test func tooFewPointsOrABadToleranceOrLimitComeBackUnreducedHoweverLong() {
        let line = (0..<30_000).map { point(Double($0), 0) }
        #expect(CanvasStrokeBuilder.reduction(of: line, tolerance: .nan, limit: 10).points.count == 30_000)
        #expect(CanvasStrokeBuilder.reduction(of: line, tolerance: 1, limit: 1).points.count == 30_000)
    }
}
