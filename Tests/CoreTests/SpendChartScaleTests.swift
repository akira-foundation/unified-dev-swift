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
    @Test("a week names every day and a month names one in seven")
    func stride() {
        #expect(SpendChartScale.labelled(days(7), naming: name).count == 7)
        #expect(SpendChartScale.labelled(days(30), naming: name).count == 5)
    }

    @Test("the latest day is always named, whatever the stride lands on")
    func lastDayNamed() {
        for count in [1, 7, 11, 30] {
            let shown = SpendChartScale.labelled(days(count), naming: name)
            #expect(shown.last == name(days(count)[count - 1]))
        }
    }

    @Test("bars thin out as the window widens, and never reach zero")
    func width() {
        let week = SpendChartScale.barWidth(for: 7)
        let month = SpendChartScale.barWidth(for: 30)
        #expect(week > month)
        #expect(month > 0)
    }
}
