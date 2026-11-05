import Foundation
import Testing
@testable import Core

@Suite("Simplifying a long stroke")
struct CanvasStrokeSimplificationTests {
    private func point(_ x: Double, _ y: Double) -> CanvasPoint { CanvasPoint(x: x, y: y) }

    @Test func aNoisyZigzagStaysWithinTheToleranceItWasReducedWith() {
        let zigzag = (0..<6_000).map { point(Double($0), $0 % 2 == 0 ? 0 : 16) }
        let reduction = CanvasStrokeBuilder.reduction(of: zigzag, tolerance: 1.5, limit: CanvasStrokeBuilder.inputLimit)
        #expect(reduction.points.count <= CanvasStrokeBuilder.inputLimit)
        #expect(reduction.coarsened && reduction.tolerance > 1.5)
        #expect(CanvasDeviation.max(of: zigzag, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aCursiveStaysWithinTheToleranceItWasReducedWith() {
        let cursive = CanvasDeviation.cursive(8_000)
        let reduction = CanvasStrokeBuilder.reduction(of: cursive, tolerance: 0.05, limit: 1_000)
        #expect(reduction.points.count <= 1_000)
        #expect(CanvasDeviation.max(of: cursive, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aSpikeSpacedAboveTheToleranceSurvives() {
        var line = (0..<20_000).map { point(Double($0), 0) }
        line[10_001] = point(10_001, 50)
        let reduction = CanvasStrokeBuilder.reduction(of: line, tolerance: 0.5, limit: CanvasStrokeBuilder.inputLimit)
        #expect(reduction.points.contains(point(10_001, 50)))
        #expect(reduction.points.first == line.first && reduction.points.last == line.last)
        #expect(CanvasDeviation.max(of: line, from: reduction.points) <= reduction.tolerance + 1e-9)
    }

    @Test func aCornerSpacedAboveTheToleranceIsKeptExactly() {
        let leg = 6_000
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

    @Test func aSawtoothOfTenThousandPointsDoesNotStall() {
        let sawtooth = (0..<10_000).map { point(Double($0), Double($0 % 7) * 40) }
        let started = Date()
        let reduction = CanvasStrokeBuilder.reduction(of: sawtooth, tolerance: 1, limit: CanvasStrokeBuilder.inputLimit)
        let seconds = Date().timeIntervalSince(started)
        print("MEASURE sawtooth of 10000 points reduced in \(seconds) s to \(reduction.points.count) points at tolerance \(reduction.tolerance)")
        #expect(seconds < 5)
        #expect(reduction.points.count <= CanvasStrokeBuilder.inputLimit)
    }
}
