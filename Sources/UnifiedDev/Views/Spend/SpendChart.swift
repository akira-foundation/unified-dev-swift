import SwiftUI
import Core

struct SpendChart: View {
    let board: SpendBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            SpendBarRow(
                bars: board.bars,
                spacing: board.bars.count > 10 ? 3 : 6,
                corner: 3,
                showsDays: board.bars.count <= 10
            )
            .frame(height: Self.height)
            if let dearest = SpendBars.dearest(board.bars), !dearest.spend.isEmpty {
                Text(SpendLines.dearestDay(dearest))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    static let height: CGFloat = 160
}
