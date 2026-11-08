import SwiftUI
import Core

struct CanvasNoticeLines: View {
    let notice: CanvasNotice

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            ForEach(notice.lines, id: \.self) { line in
                Text(verbatim: line)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct CanvasNoticeStrip: View {
    let notice: CanvasNotice
    let dismiss: () -> Void

    var body: some View {
        WorkspaceNoticeStrip(tone: notice.tone, title: notice.title, onDismiss: dismiss) {
            CanvasNoticeLines(notice: notice)
        } actions: {
            EmptyView()
        }
    }
}
