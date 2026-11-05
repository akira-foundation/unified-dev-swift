import SwiftUI
import Core

struct CanvasExportNoticeLines: View {
    let notice: CanvasExportNotice

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

struct CanvasExportNoticeStrip: View {
    let notice: CanvasExportNotice
    let dismiss: () -> Void

    var body: some View {
        WorkspaceNoticeStrip(tone: notice.tone, title: notice.title, onDismiss: dismiss) {
            CanvasExportNoticeLines(notice: notice)
        } actions: {
            EmptyView()
        }
    }
}
