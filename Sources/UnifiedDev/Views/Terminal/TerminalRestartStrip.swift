import SwiftUI
import Core

struct TerminalRestartStrip: View {
    var command: String
    var onStart: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "arrow.clockwise")
                .imageScale(.small)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                .accessibilityHidden(true)

            Text("Was running here")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .layoutPriority(1)

            Text(verbatim: command)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(command)

            Spacer(minLength: 0)

            Button("Start", action: onStart)
                .controlSize(.small)
                .accessibilityLabel("Start \(command)")

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .help("Forget this command")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacing)
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
