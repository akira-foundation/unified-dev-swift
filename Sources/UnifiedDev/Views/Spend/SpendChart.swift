import Charts
import SwiftUI
import Core

struct SpendChart: View {
    let board: SpendBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Chart(board.bars) { bar in
                BarMark(
                    x: .value(SpendLines.dayAxis, bar.day, unit: .day),
                    y: .value(SpendLines.costAxis, bar.spend.cost.total),
                    width: .ratio(Self.barWidth)
                )
                .foregroundStyle(Palette.controlAccent)
                .cornerRadius(Self.corner)
                .accessibilityLabel(SpendFormat.day(bar.day))
                .accessibilityValue(SpendLines.cost(bar.spend))
            }
            .chartXAxis { xAxis }
            .chartYAxis { yAxis }
            .chartYScale(domain: .automatic(includesZero: true))
            .frame(height: Self.height)
            if let dearest = board.dearestDay, !dearest.spend.isEmpty {
                Text(SpendLines.dearestDay(dearest))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    static let height: CGFloat = 200
    static let barWidth = 0.6
    static let corner: CGFloat = 3

    private var stride: Int { board.bars.count > 10 ? 7 : 1 }

    private var xAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: stride)) { value in
            AxisTick()
            AxisValueLabel {
                if let day = value.as(Date.self) {
                    Text(SpendFormat.day(day))
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    private var yAxis: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(SpendFormat.money(amount))
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }
}
