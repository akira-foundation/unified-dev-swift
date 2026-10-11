import SwiftUI
import Core

struct SpendScreenView: View {
    @Environment(AppModel.self) private var app

    @State private var span = SpendSpan.week

    var body: some View {
        let board = app.spendBoard(span: span)
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.gutter) {
                header(board)
                card { SpendChart(board: board) }
                card { SpendColumnsTable(board: board) }
                card { providers(board) }
                card { SpendProjectsList(projects: board.projects) }
            }
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.windowBackground)
        .frame(minWidth: 560, minHeight: 420)
        .task { app.refreshSpend() }
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surfaceRaised)
            )
    }

    private func header(_ board: SpendBoard) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
                    Text(SpendLines.cost(board.total))
                        .font(Typo.displayHeading)
                        .monospacedDigit()
                    Text(SpendLines.tokensLine(board.total.usage.total))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Text(SpendFormat.measuredOn(board.pricedOn))
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: Metrics.spacing)
            Picker("", selection: $span) {
                ForEach(SpendSpan.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
        }
    }

    private func providers(_ board: SpendBoard) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            Text(SpendLines.byProvider)
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(board.providers) { provider in
                HStack(spacing: Metrics.spacing) {
                    SpendProviderDot(kind: provider.kind, label: provider.kind.label)
                    Spacer(minLength: Metrics.spacing)
                    if provider.turns > 0 {
                        Text(SpendLines.turns(provider.turns))
                            .font(Typo.micro)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Text(SpendLines.providerLine(provider))
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
