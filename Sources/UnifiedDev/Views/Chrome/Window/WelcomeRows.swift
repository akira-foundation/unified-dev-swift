import SwiftUI
import Core

struct WelcomeHighlightRow: View {
    let highlight: WelcomeHighlight

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.inset + Metrics.spacingSmall) {
            Image(systemName: highlight.symbol)
                .font(.system(size: 20))
                .foregroundStyle(Palette.controlAccent)
                .frame(width: 26, alignment: .center)
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

struct WelcomeOfferRow<Control: View>: View {
    let symbol: String
    let headline: String
    let detail: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.inset + Metrics.spacingSmall) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 26, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
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

            control()
        }
    }
}
