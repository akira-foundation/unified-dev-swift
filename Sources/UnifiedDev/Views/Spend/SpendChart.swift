import Charts
import SwiftUI
import Core

struct SpendChart: View {
    let board: SpendBoard

    var body: some View {
        Chart(board.slices) { slice in
            BarMark(
                x: .value(SpendLines.dayAxis, SpendFormat.day(slice.day)),
                y: .value(SpendLines.costAxis, slice.spend.cost.total),
                width: .fixed(width)
            )
            .foregroundStyle(by: .value(SpendLines.providerAxis, slice.provider.label))
            .cornerRadius(Self.corner, style: .continuous)
            .accessibilityLabel("\(SpendFormat.day(slice.day)), \(slice.provider.label)")
            .accessibilityValue(SpendLines.cost(slice.spend))
        }
        .chartForegroundStyleScale(domain: names, range: colours)
        .chartLegend(position: .bottom, alignment: .leading, spacing: Metrics.spacingWide)
        .chartXScale(domain: labels)
        .chartYAxis(.hidden)
        .chartXAxis { xAxis }
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) {
                Rectangle().fill(Palette.border).frame(height: 1)
            }
            }
        .frame(height: Self.height)
        .accessibilityLabel(SpendLines.title + ", " + board.window.label)
    }

    static let height: CGFloat = 112
    static let corner: CGFloat = 3

    private var drawn: [SpendBoard.ProviderLine] {
        board.providers.filter { !$0.spend.isEmpty }
    }

    private var names: [String] { drawn.map(\.kind.label) }

    private var colours: [Color] { drawn.map { Color(hexString: ProviderAccent.hex(for: $0.kind)) } }

    private var days: [Date] { board.bars.map(\.day) }

    private var labels: [String] { days.map { SpendFormat.day($0) } }

    private var named: [String] { SpendChartScale.labelled(days, naming: SpendFormat.day) }

    private var width: CGFloat { SpendChartScale.barWidth(for: days.count) }

    private var xAxis: some AxisContent {
        AxisMarks(values: named) { value in
            AxisValueLabel {
                if let day = value.as(String.self) {
                    Text(day)
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }
}
