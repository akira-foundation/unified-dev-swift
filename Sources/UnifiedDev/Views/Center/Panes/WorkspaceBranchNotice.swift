import SwiftUI
import Core

struct WorkspaceBranchNotice: View {
    var workspaceID: WorkspaceID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fontScale) private var fontScale

    private var notices: BranchKeptNotices { .shared }

    var body: some View {
        let notice = notices.notices[workspaceID]

        VStack(spacing: 0) {
            if let notice {
                WorkspaceNoticeStrip(
                    tone: .information, title: notice.title,
                    onDismiss: { notices.dismiss(workspaceID) }
                ) {
                    Text(runs: notice.reason, rung: Typo.caption, scale: fontScale)
                        .foregroundStyle(Palette.textSecondary)
                        .layoutPriority(1)
                        .textSelection(.enabled)
                } actions: {
                    EmptyView()
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.pane, value: notice)
        .id(workspaceID)
    }
}
