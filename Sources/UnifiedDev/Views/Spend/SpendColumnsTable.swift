import SwiftUI
import Core

struct SpendColumnsTable: View {
    let board: SpendBoard

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text(SpendLines.whereItWent)
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
            SpendShareBar(columns: board.columns)
            VStack(spacing: Metrics.spacingTight) {
                ForEach(board.columns) { column in
                    row(column)
                }
            }
            footer
        }
    }

    private func row(_ column: SpendBoard.ColumnLine) -> some View {
        HStack(spacing: Metrics.spacing) {
            Circle()
                .fill(SpendShareBar.ink(for: column.column))
                .frame(width: 7, height: 7)
            Text(column.column.label)
                .font(Typo.caption)
                .frame(width: 92, alignment: .leading)
            Text(SpendFormat.tokens(column.tokens))
                .font(Typo.codeTiny)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 72, alignment: .trailing)
            Text(SpendFormat.share(column.tokenShare))
                .font(Typo.codeTiny)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 56, alignment: .trailing)
            Spacer(minLength: Metrics.spacing)
            Text(SpendLines.columnCost(column, in: board.total))
                .font(Typo.codeTiny)
                .frame(width: 90, alignment: .trailing)
            Text(SpendFormat.share(column.costShare))
                .font(Typo.codeTiny)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(SpendLines.savedLine(board.total.cost))
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
            if board.total.hasUnpricedTokens {
                Text(SpendLines.unpricedLine(board.total.unpriced))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

struct SpendShareBar: View {
    let columns: [SpendBoard.ColumnLine]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(columns) { column in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Self.ink(for: column.column))
                        .frame(width: max(0, proxy.size.width * column.costShare - 2))
                }
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpendLines.whereItWent)
    }

    static func ink(for column: TokenColumn) -> Color {
        Palette.controlAccent.opacity(opacity(for: column))
    }

    static func opacity(for column: TokenColumn) -> Double {
        switch column {
        case .freshInput: 0.35
        case .cacheRead: 0.55
        case .cacheWrite: 0.75
        case .output: 1
        }
    }
}
