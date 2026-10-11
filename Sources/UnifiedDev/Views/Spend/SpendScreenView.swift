import SwiftUI
import Core

struct SpendScreenView: View {
    @Environment(AppModel.self) private var app

    @State private var span = SpendSpan.week

    var body: some View {
        let board = app.spendBoard(span: span)
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.gutter * 2) {
                header(board)
                SpendChart(board: board)
                SpendColumnsTable(board: board)
                providers(board)
                SpendProjectsList(projects: board.projects)
            }
            .padding(Metrics.gutter * 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.windowBackground)
        .frame(minWidth: 640, minHeight: 480)
        .task { app.refreshSpend() }
    }

    private func header(_ board: SpendBoard) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.gutter) {
                Text(SpendLines.cost(board.total))
                    .font(Typo.display)
                    .monospacedDigit()
                Text(SpendLines.tokensLine(board.total.usage.total))
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: Metrics.gutter)
                Picker("", selection: $span) {
                    ForEach(SpendSpan.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
            Text(SpendFormat.measuredOn(board.pricedOn))
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func providers(_ board: SpendBoard) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text(SpendLines.byProvider)
                .font(Typo.title)
                .accessibilityAddTraits(.isHeader)
            ForEach(board.providers) { provider in
                HStack(spacing: Metrics.spacingWide) {
                    Text(provider.kind.label)
                        .font(Typo.labelEmphasis)
                    Spacer(minLength: Metrics.spacingWide)
                    if provider.turns > 0 {
                        Text(SpendLines.turns(provider.turns))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Text(SpendLines.providerLine(provider))
                        .font(Typo.codeSmall)
                        .foregroundStyle(Palette.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
