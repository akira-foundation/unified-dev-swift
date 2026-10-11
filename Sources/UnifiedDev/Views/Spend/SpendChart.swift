import Charts
import SwiftUI
import Core

struct SpendChart: View {
    let board: SpendBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Chart(board.slices) { slice in
                BarMark(
                    x: .value(SpendLines.dayAxis, slice.day, unit: .day),
                    y: .value(SpendLines.costAxis, slice.spend.cost.total),
                    width: .ratio(Self.barWidth)
                )
                .foregroundStyle(by: .value(SpendLines.providerAxis, slice.provider.label))
                .cornerRadius(Self.corner)
                .accessibilityLabel("\(SpendFormat.day(slice.day)), \(slice.provider.label)")
                .accessibilityValue(SpendLines.cost(slice.spend))
            }
            .chartForegroundStyleScale(domain: names, range: colours)
            .chartLegend(.hidden)
            .chartXAxis { xAxis }
            .chartYAxis { yAxis }
            .chartYScale(domain: .automatic(includesZero: true))
            .frame(height: Self.height)
            .accessibilityLabel(SpendLines.title + ", " + board.window.label)
            footer
        }
    }

    static let height: CGFloat = 132
    static let barWidth = 0.65
    static let corner: CGFloat = 2

    private var drawn: [SpendBoard.ProviderLine] {
        board.providers.filter { !$0.spend.isEmpty }
    }

    private var names: [String] { drawn.map(\.kind.label) }

    private var colours: [Color] { drawn.map { Color(hexString: ProviderAccent.hex(for: $0.kind)) } }

    private var footer: some View {
        HStack(spacing: Metrics.gutter) {
            ForEach(drawn) { provider in
                SpendProviderDot(kind: provider.kind, label: provider.kind.label)
            }
            Spacer(minLength: Metrics.spacing)
            if let dearest = board.dearestDay {
                Text(SpendLines.dearestDay(dearest))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    private var stride: Int { board.bars.count > 10 ? 7 : 1 }

    private var xAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: stride)) { value in
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
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine()
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(SpendFormat.axisMoney(amount))
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }
}

struct SpendProviderDot: View {
    let kind: AgentKind
    var label: String?

    var body: some View {
        HStack(spacing: Metrics.spacingTight + 2) {
            Circle()
                .fill(Color(hexString: ProviderAccent.hex(for: kind)))
                .frame(width: 7, height: 7)
            if let label {
                Text(label)
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
