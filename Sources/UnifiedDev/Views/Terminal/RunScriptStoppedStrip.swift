import SwiftUI
import Core

struct RunScriptStoppedStrip: View {
    var caption: String
    var command: String
    var onRunAgain: () -> Void
    var onCloseTab: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "stop.circle")
                .imageScale(.small)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                .accessibilityHidden(true)

            Text(caption)
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

            Button("Run Again", action: onRunAgain)
                .controlSize(.small)
                .accessibilityLabel("Run \(command) again")

            Button("Close Tab", action: onCloseTab)
                .controlSize(.small)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .help("Dismiss")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacing)
        .frame(maxWidth: .infinity)
        .background(Palette.surface)
        .overlay(alignment: .bottom) { Hairline() }
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(caption), \(command)")
    }
}
