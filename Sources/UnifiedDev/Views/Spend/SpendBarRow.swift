import SwiftUI
import Core

struct SpendBarRow: View {
    let bars: [SpendBoard.DayBar]
    var spacing: CGFloat = 3
    var corner: CGFloat = 2
    var showsDays = false

    var body: some View {
        let heights = SpendBars.heights(of: bars)
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                column(bar, height: heights[index])
            }
        }
    }

    private func column(_ bar: SpendBoard.DayBar, height: Double) -> some View {
        VStack(spacing: Metrics.spacingTight) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(height > 0 ? Palette.controlAccent : Palette.border)
                        .frame(height: max(1, proxy.size.height * height))
                }
            }
            if showsDays {
                Text(SpendFormat.day(bar.day))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpendFormat.day(bar.day))
        .accessibilityValue(SpendLines.cost(bar.spend))
    }
}
