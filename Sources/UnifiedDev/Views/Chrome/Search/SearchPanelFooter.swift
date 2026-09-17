import SwiftUI
import Core

struct SearchPanelFooter: View {
    var keys: [SearchPanelFooterKey]
    var summary: String?

    var body: some View {
        HStack(spacing: Metrics.gutter) {
            ForEach(keys) { key in
                HStack(spacing: Metrics.spacingSmall) {
                    Text(key.key)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, Metrics.chipInsetH)
                        .padding(.vertical, Metrics.chipInsetV)
                        .background(
                            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                                .fill(Palette.hover)
                        )

                    Text(key.label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                }
            }

            Spacer(minLength: Metrics.spacingWide)

            if let summary {
                Text(summary)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Metrics.inset)
        .padding(.vertical, Metrics.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Hairline() }
        .accessibilityHidden(true)
    }
}
