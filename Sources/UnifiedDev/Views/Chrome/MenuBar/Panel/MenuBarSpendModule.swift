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
                    .frame(height: Self.barHeight)
                providers
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuBarModule(SpendLines.shortTitle)
        .accessibilityLabel(SpendLines.shortTitle)
        .accessibilityValue(SpendFormat.money(board.total.cost.total))
        .accessibilityHint(SpendLines.openScreen)
        .panelFocus(focus, .spend)
        .help(SpendFormat.measuredOn(board.pricedOn))
    }

    static let barHeight: CGFloat = 22

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
            Text(SpendLines.shortTitle)
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

struct SpendSparkline: View {
    let bars: [SpendBoard.DayBar]

    var body: some View {
        let heights = SpendBars.heights(of: bars)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(heights[index] > 0 ? MenuInk.normal : MenuInk.track)
                            .frame(height: max(1, proxy.size.height * heights[index]))
                    }
                }
                .accessibilityLabel(SpendFormat.day(bar.day))
                .accessibilityValue(SpendFormat.money(bar.spend.cost.total))
            }
        }
    }
}
