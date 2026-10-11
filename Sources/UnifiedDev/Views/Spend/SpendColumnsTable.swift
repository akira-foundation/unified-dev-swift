import SwiftUI
import Core

struct SpendColumnsTable: View {
    let board: SpendBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            heading
            ForEach(board.columns) { column in
                row(column)
            }
            Divider()
            footer
        }
    }

    private var heading: some View {
        HStack {
            Text(SpendLines.whereItWent)
                .font(Typo.title)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(SpendFormat.measuredOn(board.pricedOn))
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private func row(_ column: SpendBoard.ColumnLine) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            Text(column.column.label)
                .font(Typo.label)
                .frame(width: 110, alignment: .leading)
            Text(SpendFormat.tokens(column.tokens))
                .font(Typo.codeSmall)
                .frame(width: 90, alignment: .trailing)
            Text(SpendFormat.share(column.tokenShare))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 70, alignment: .trailing)
            Text(SpendLines.columnCost(column, in: board.total))
                .font(Typo.codeSmall)
                .frame(width: 110, alignment: .trailing)
            Text(SpendFormat.share(column.costShare))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 70, alignment: .trailing)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            Text(SpendLines.savedLine(board.total.cost))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
            if board.total.hasUnpricedTokens {
                Text(SpendLines.unpricedLine(board.total.unpriced))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}
