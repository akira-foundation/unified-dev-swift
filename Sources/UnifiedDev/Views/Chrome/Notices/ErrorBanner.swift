import SwiftUI

struct ErrorBanner: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.gutter) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.negative)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                Text(title)
                    .font(Typo.labelEmphasis)
                Text(message)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .textSelection(.enabled)

            Spacer(minLength: Metrics.gutter)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(Palette.textSecondary)
            .help("Dismiss")
        }
        .padding(Metrics.gutter)
        .background(
            Palette.negative.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Metrics.corner)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
