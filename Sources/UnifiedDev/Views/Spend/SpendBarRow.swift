import Charts
import SwiftUI
import Core

struct SpendSparkline: View {
    let bars: [SpendBoard.DayBar]

    var body: some View {
        Chart(bars) { bar in
            AreaMark(
                x: .value(SpendLines.dayAxis, bar.day, unit: .day),
                y: .value(SpendLines.costAxis, bar.spend.cost.total)
            )
            .foregroundStyle(Self.fill)
            .interpolationMethod(.monotone)
            LineMark(
                x: .value(SpendLines.dayAxis, bar.day, unit: .day),
                y: .value(SpendLines.costAxis, bar.spend.cost.total)
            )
            .foregroundStyle(MenuInk.normal)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            .interpolationMethod(.monotone)
            .accessibilityLabel(SpendFormat.day(bar.day))
            .accessibilityValue(SpendLines.cost(bar.spend))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: true))
        .chartPlotStyle { $0.padding(.vertical, 1) }
    }

    static let fill = LinearGradient(
        colors: [MenuInk.normal.opacity(0.35), MenuInk.normal.opacity(0.04)],
        startPoint: .top,
        endPoint: .bottom
    )
}
