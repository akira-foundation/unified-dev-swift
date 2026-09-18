import SwiftUI
import Core

struct ErrorBanner: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        NoticePiece(
            tone: .error,
            announcement: NoticeTone.error.spoken(title, message),
            onDismiss: onDismiss
        ) {
            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                Text(title)
                    .font(Typo.labelEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .textSelection(.enabled)
        }
        .noticeGlass(.error)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
