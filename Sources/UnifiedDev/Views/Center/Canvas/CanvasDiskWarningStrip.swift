import SwiftUI
import Core

struct CanvasDiskWarningStrip: View {
    let warning: CanvasDiskWarning
    let perform: (CanvasDiskWarningAction) -> Void

    var body: some View {
        WorkspaceNoticeStrip(tone: warning.tone, title: warning.title) {
            Text(verbatim: warning.message)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(4)
                .layoutPriority(1)
                .textSelection(.enabled)
        } actions: {
            ForEach(warning.actions, id: \.self) { action in
                Button(action.title) { perform(action) }
            }
        }
    }
}
