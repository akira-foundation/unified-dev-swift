import SwiftUI
import Core
struct StartProjectFetching: View {
    var isSlow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(spacing: Metrics.spacingWide) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                Text("Cloning the repository")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cloning the repository")
            .accessibilityValue("Running")

            if isSlow {
                Callout(
                    text: RepositoryCloner.slowNotice,
                    symbol: "clock.badge.exclamationmark",
                    tone: .warning
                )
            }
        }
    }
}
