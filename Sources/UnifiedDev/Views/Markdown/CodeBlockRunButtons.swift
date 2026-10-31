import SwiftUI
import Core

struct CodeBlockRunButtons: View {
    var command: String
    var isRunning: Bool
    var run: @MainActor @Sendable (String) -> Void
    var stop: @MainActor @Sendable (String) -> Void

    var body: some View {
        if isRunning {
            icon("stop.fill", title: "Stop") { stop(command) }
        } else {
            icon("play", title: "Run and send the output to the agent") { run(command) }
        }
    }

    private func icon(_ symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Typo.caption)
                .imageScale(.medium)
                .frame(width: 16, height: 16)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: MarkdownMetrics.iconButton, height: MarkdownMetrics.iconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}
