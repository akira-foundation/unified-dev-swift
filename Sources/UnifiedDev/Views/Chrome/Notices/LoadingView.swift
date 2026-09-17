import SwiftUI

struct LoadingView: View {
    let label: String?

    init(_ label: String? = nil) {
        self.label = label
    }

    var body: some View {
        HStack(spacing: Metrics.spacingWide) {
            ProgressView()
                .controlSize(.small)

            if let label {
                Text(label)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? "Loading")
    }
}
