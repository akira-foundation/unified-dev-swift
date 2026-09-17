import SwiftUI
import Core

struct PendingWorkspaceRow: View {
    var pending: PendingWorkspace

    var body: some View {
        Label {
            HStack(spacing: Metrics.spacing) {
                Text(pending.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Palette.textSecondary)

                Spacer(minLength: 0)
            }
        } icon: {
            WorkspaceStatusGlyph(status: .settingUp)
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, SidebarMetrics.rowIndent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(pending.name))
        .accessibilityValue(Text("Creating"))
        .help("Creating this workspace")
    }
}
