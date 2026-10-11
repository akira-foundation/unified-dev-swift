import Testing
import Foundation
@testable import Core

private func days(_ count: Int) -> [Date] {
    (0..<count).map { Date(timeIntervalSince1970: Double($0) * 86_400) }
}

private func name(_ date: Date) -> String {
    "\(Int(date.timeIntervalSince1970 / 86_400))"
}

@Suite("Spend chart scale")
struct SpendChartScaleTests {
    @Test("up to ten bars name every day, and above that one in seven")
    func stride() {
        #expect(SpendChartScale.labelStride(for: 7) == 1)
        #expect(SpendChartScale.labelStride(for: 8) == 1)
        #expect(SpendChartScale.labelStride(for: 10) == 1)
        #expect(SpendChartScale.labelStride(for: 11) == 7)
        #expect(SpendChartScale.labelled(days(7), naming: name).count == 7)
        #expect(SpendChartScale.labelled(days(10), naming: name).count == 10)
        #expect(SpendChartScale.labelled(days(11), naming: name).count == 2)
        #expect(SpendChartScale.labelled(days(30), naming: name).count == 5)
    }

    @Test("the latest day is always named, whatever the stride lands on")
    func lastDayNamed() {
        for count in [1, 7, 11, 30] {
            let shown = SpendChartScale.labelled(days(count), naming: name)
            #expect(shown.last == name(days(count)[count - 1]))
        }
    }

    @Test("a bar thins at eight days and again at fifteen, and never reaches zero")
    func width() {
        let week = SpendChartScale.barWidth(for: 7)
        let fortnight = SpendChartScale.barWidth(for: 8)
        let month = SpendChartScale.barWidth(for: 15)
        #expect(week > fortnight)
        #expect(fortnight > month)
        #expect(SpendChartScale.barWidth(for: 14) == fortnight)
        #expect(SpendChartScale.barWidth(for: 30) == month)
        #expect(month > 0)
    }
}
