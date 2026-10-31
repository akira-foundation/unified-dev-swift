import SwiftUI
import Core

struct HomeStatusBar: View {
    var summary: String
    var compaction: Compaction?
    var deletion: Deletion?

    struct Deletion {
        var title: String
        var help: String
        var run: () -> Void
    }

    struct Compaction {
        var help: String
        var isRunning: Bool
        var run: () -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacing) {
                Text(summary)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Showing \(summary)")

                if let deletion { button(deletion) }

                if let compaction { button(compaction) }
            }
            .padding(.horizontal, HomeMetrics.gutter)
            .frame(height: Metrics.barHeight)
        }
    }

    private func button(_ deletion: Deletion) -> some View {
        Button(deletion.title, role: .destructive, action: deletion.run)
            .controlSize(.small)
            .help(deletion.help)
    }

    private func button(_ compaction: Compaction) -> some View {
        Button(compaction.isRunning ? "Compacting" : "Compact", action: compaction.run)
            .controlSize(.small)
            .disabled(compaction.isRunning)
            .help(compaction.help)
    }
}
