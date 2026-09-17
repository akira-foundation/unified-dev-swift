import SwiftUI
import Core

struct FeedbackLogSheet: View {
    var text: String
    var onClose: @MainActor () -> Void

    private static let height: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            VStack(alignment: .leading, spacing: Metrics.spacingWide) {
                Text(Feedback.Copy.logsTitle)
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)

                Text(Feedback.Copy.logsDetail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.vertical) {
                Text(text.isEmpty ? AppLogExcerpt.empty : text)
                    .font(Typo.codeSmall)
                    .foregroundStyle(Palette.textPrimary)
                    .textSelection(.enabled)
                    .padding(Metrics.inset)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .defaultScrollAnchor(.topLeading)
            .frame(height: Self.height)
            .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.corner)
                    .strokeBorder(Palette.border, lineWidth: Metrics.outline)
            )

            HStack(spacing: Metrics.gutter) {
                Text(lineCount)
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)

                Spacer(minLength: Metrics.gutter)

                Button("Copy") { Clipboard.copy(text) }
                    .disabled(text.isEmpty)

                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Metrics.pane)
        .frame(width: 700)
        .background(Palette.surface)
    }

    private var lineCount: String {
        guard !text.isEmpty else { return "Nothing to send" }
        let lines = LogTail.lineCount(text)
        return lines == 1 ? "1 line" : "\(lines) lines"
    }
}
