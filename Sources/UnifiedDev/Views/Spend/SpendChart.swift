import SwiftUI
import Core

struct SpendChart: View {
    let board: SpendBoard

    var body: some View {
        let heights = SpendBars.heights(of: board.bars)
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(board.bars.enumerated()), id: \.element.id) { index, bar in
                    column(bar, height: heights[index])
                }
            }
            .frame(height: Self.height)
            if let dearest = SpendBars.dearest(board.bars), dearest.spend.cost.total > 0 {
                Text("Dearest day: \(SpendFormat.day(dearest.day)), \(SpendFormat.money(dearest.spend.cost.total))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    static let height: CGFloat = 160

    private var gap: CGFloat { board.bars.count > 10 ? 3 : 6 }

    private func column(_ bar: SpendBoard.DayBar, height: Double) -> some View {
        VStack(spacing: Metrics.spacingTight) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(height > 0 ? Palette.controlAccent : Palette.border)
                        .frame(height: max(1, proxy.size.height * height))
                }
            }
            if board.bars.count <= 10 {
                Text(SpendFormat.day(bar.day))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpendFormat.day(bar.day))
        .accessibilityValue(SpendFormat.money(bar.spend.cost.total))
    }
}
