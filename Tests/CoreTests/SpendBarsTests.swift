import Testing
import Foundation
@testable import Core

private func bar(_ cost: Double, day: Int) -> SpendBoard.DayBar {
    SpendBoard.DayBar(
        day: Date(timeIntervalSince1970: Double(day) * 86_400),
        spend: Spend(usage: TokenUsage(output: 1), cost: SpendCost(output: cost))
    )
}

@Suite("Spend bars")
struct SpendBarsTests {
    @Test("the dearest day fills the bar and the others are measured against it")
    func heightsAreRelative() {
        let heights = SpendBars.heights(of: [bar(10, day: 1), bar(5, day: 2), bar(0, day: 3)])
        #expect(heights[0] == 1)
        #expect(heights[1] == 0.5)
        #expect(heights[2] == 0)
    }

    @Test("a day that cost something is never drawn as nothing")
    func smallDaysStayVisible() {
        let heights = SpendBars.heights(of: [bar(1000, day: 1), bar(0.01, day: 2)])
        #expect(heights[1] == SpendBars.floor)
    }

    @Test("a week with no spend draws no bars at all")
    func emptyWeek() {
        #expect(SpendBars.heights(of: [bar(0, day: 1), bar(0, day: 2)]) == [0, 0])
    }

    @Test("the dearest day is the one to name")
    func dearest() {
        #expect(SpendBars.dearest([bar(1, day: 1), bar(9, day: 2)])?.spend.cost.total == 9)
        #expect(SpendBars.dearest([]) == nil)
    }
}
