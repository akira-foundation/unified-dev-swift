import SwiftUI
import Core

struct WelcomeHighlightRow: View {
    let highlight: WelcomeHighlight

    private static let symbolColumn: CGFloat = 34
    private static let symbolSize: CGFloat = 25

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.inset + Metrics.spacingWide) {
            Image(systemName: highlight.symbol)
                .font(.system(size: Self.symbolSize))
                .foregroundStyle(Palette.controlAccent)
                .frame(width: Self.symbolColumn, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Text(highlight.headline)
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)

                Text(highlight.detail)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct WelcomeToggleRow: View {
    let symbol: String
    let headline: String
    let detail: String
    @Binding var isOn: Bool
    var isEnabled = true

    private static let symbolColumn: CGFloat = 34
    private static let symbolSize: CGFloat = 20

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.inset + Metrics.spacingWide) {
            Image(systemName: symbol)
                .font(.system(size: Self.symbolSize))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Self.symbolColumn, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Text(headline)
                    .font(Typo.bodyEmphasis)
                    .foregroundStyle(Palette.textPrimary)

                Text(detail)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: Metrics.spacingWide)

            Toggle(headline, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!isEnabled)
                .accessibilityIdentifier("welcome-toggle-\(symbol)")
        }
    }
}
