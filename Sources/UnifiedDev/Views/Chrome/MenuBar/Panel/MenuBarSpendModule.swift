import SwiftUI
import Core

struct MenuBarSpendModule: View {
    let board: SpendBoard
    var focus: FocusState<MenuBarPanelFocus?>.Binding?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                header
                SpendSparkline(bars: board.bars)
                    .frame(height: Self.chartHeight)
                providers
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuBarModule(SpendLines.title)
        .accessibilityLabel(SpendLines.title)
        .accessibilityValue(SpendLines.cost(board.total))
        .accessibilityHint(SpendLines.openScreen)
        .panelFocus(focus, .spend)
        .help(SpendFormat.measuredOn(board.pricedOn))
    }

    static let chartHeight: CGFloat = 26

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
            Text(SpendLines.title)
                .font(UsageScale.header)
                .foregroundStyle(MenuInk.primary)
                .accessibilityAddTraits(.isHeader)
            Text(board.window.label)
                .font(UsageScale.plan)
                .foregroundStyle(MenuInk.secondary)
            Spacer(minLength: Metrics.spacingWide)
            Text(SpendFormat.money(board.total.cost.total))
                .font(UsageScale.label)
                .foregroundStyle(MenuInk.primary)
                .monospacedDigit()
        }
    }

    private var providers: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            ForEach(board.providers) { provider in
                HStack(spacing: Metrics.spacing) {
                    Circle()
                        .fill(Color(hexString: ProviderAccent.hex(for: provider.kind)))
                        .frame(width: 7, height: 7)
                    Text(provider.kind.label)
                        .font(UsageScale.supporting)
                        .foregroundStyle(MenuInk.primary)
                    Spacer(minLength: Metrics.spacing)
                    Text(SpendLines.providerLine(provider))
                        .font(UsageScale.supporting)
                        .foregroundStyle(MenuInk.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}
