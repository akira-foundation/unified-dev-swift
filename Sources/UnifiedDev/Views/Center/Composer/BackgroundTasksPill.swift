import SwiftUI
import Core

struct BackgroundTasksPill: View {
    var transcript: TranscriptModel
    var onOpen: @MainActor () -> Void

    var body: some View {
        let list = BackgroundTaskList(transcript.subagents)
        if let label = list.label {
            Button(action: onOpen) {
                HStack(spacing: Metrics.spacingWide) {
                    if list.runningCount > 0 {
                        SubagentMarkGlyph(mark: .working)
                    } else {
                        Image(systemName: InspectorTab.tasks.symbol)
                            .font(Typo.captionEmphasis)
                            .foregroundStyle(Palette.textSecondary)
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .font(Typo.captionEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                }
                .padding(.horizontal, Metrics.gutter)
                .frame(height: Metrics.barHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: Capsule())
            .pointerStyle(.link)
            .help("Show the background tasks in the inspector")
            .accessibilityLabel(Text(list.spokenLabel ?? label))
        }
    }
}
