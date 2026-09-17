import Foundation
import Testing
@testable import Core

struct DiffRunGroupingTests {
    private enum Row {
        case line
        case other
    }

    private func chunks(_ rows: [Row], limit: Int = DiffRunGrouping.runLimit) -> [DiffRunGrouping.Chunk] {
        DiffRunGrouping.chunks(
            count: rows.count, isLine: { rows[$0] == .line }, limit: limit
        )
    }

    @Test func nothingGroupsIntoNothing() {
        #expect(chunks([]).isEmpty)
    }

    @Test func aStretchOfLinesIsOneRun() {
        #expect(chunks([.line, .line, .line, .line]) == [.run(0..<4)])
    }

    @Test func aLoneLineStaysASingleRatherThanARunOfOne() {
        #expect(chunks([.line]) == [.single(0)])
        #expect(chunks([.other, .line, .other]) == [.single(0), .single(1), .single(2)])
    }

    @Test func aRowThatIsNotALineBreaksTheRun() {
        #expect(
            chunks([.line, .line, .other, .line, .line, .line])
                == [.run(0..<2), .single(2), .run(3..<6)]
        )
    }

    @Test func aBreakAtEitherEndLeavesTheRunWhole() {
        #expect(chunks([.other, .line, .line]) == [.single(0), .run(1..<3)])
        #expect(chunks([.line, .line, .other]) == [.run(0..<2), .single(2)])
    }

    @Test func consecutiveBreaksEachStandAlone() {
        #expect(
            chunks([.line, .other, .other, .line, .line])
                == [.single(0), .single(1), .single(2), .run(3..<5)]
        )
    }

    @Test func aBandUnderEveryLineGroupsNothing() {
        let rows: [Row] = Array(repeating: [.line, .other], count: 5).flatMap(\.self)

        #expect(chunks(rows) == (0..<10).map { .single($0) })
    }

    @Test func aRunLongerThanTheLimitIsSplitAtIt() {
        #expect(
            chunks(Array(repeating: .line, count: 900), limit: 400)
                == [.run(0..<400), .run(400..<800), .run(800..<900)]
        )
    }

    @Test func aSplitLeavingOneLineLeavesASingle() {
        #expect(
            chunks(Array(repeating: .line, count: 401), limit: 400)
                == [.run(0..<400), .single(400)]
        )
    }

    @Test func aRunExactlyTheLimitIsNotSplit() {
        #expect(chunks(Array(repeating: .line, count: 400), limit: 400) == [.run(0..<400)])
    }

    @Test func anImpossibleLimitIsFlooredRatherThanObeyed() {
        #expect(chunks(Array(repeating: .line, count: 4), limit: 0) == [.run(0..<2), .run(2..<4)])
        #expect(chunks(Array(repeating: .line, count: 4), limit: 1) == [.run(0..<2), .run(2..<4)])
    }

    @Test func theChunksCoverEveryRowExactlyOnceInOrder() {
        let rows: [Row] = [
            .other, .line, .line, .line, .other, .line, .other, .other, .line, .line,
        ]

        var covered: [Int] = []
        for chunk in chunks(rows) {
            switch chunk {
            case let .single(index): covered.append(index)
            case let .run(range): covered.append(contentsOf: range)
            }
        }

        #expect(covered == Array(rows.indices))
    }

    @Test func theChunksCoverEveryRowExactlyOnceUnderTheCapToo() {
        var covered: [Int] = []
        for chunk in chunks(Array(repeating: .line, count: 1_001), limit: 7) {
            switch chunk {
            case let .single(index): covered.append(index)
            case let .run(range): covered.append(contentsOf: range)
            }
        }

        #expect(covered == Array(0..<1_001))
    }
}
