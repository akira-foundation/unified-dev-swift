import SwiftUI
import Core

struct WorkspaceDraftRow: View {
    var isCreating: Bool

    var body: some View {
        Label {
            HStack(spacing: Metrics.spacing) {
                Text(WorkspaceDraftRows.title)
                    .italic()
                    .lineLimit(1)
                    .foregroundStyle(Palette.textSecondary)

                Spacer(minLength: 0)
            }
        } icon: {
            if isCreating {
                WorkspaceStatusGlyph(status: .settingUp)
            } else {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, SidebarMetrics.rowIndent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(WorkspaceDraftRows.accessibilityLabel))
        .accessibilityValue(Text(isCreating ? "Creating" : ""))
        .help(isCreating ? "Creating this workspace" : "A workspace not created yet")
    }
}
