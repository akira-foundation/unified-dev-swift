import SwiftUI
import Core

struct WorkspaceDraftRow: View {
    var isCreating: Bool
    var trailingRepo: Repo?

    @Environment(\.sidebarRowIndent) private var rowIndent

    var body: some View {
        Label {
            HStack(spacing: Metrics.spacing) {
                Text(WorkspaceDraftRows.title)
                    .italic()
                    .lineLimit(1)
                    .foregroundStyle(Palette.textSecondary)

                Spacer(minLength: 0)

                if let trailingRepo {
                    RepoIcon(repo: trailingRepo, size: Metrics.repoIconSmall)
                        .frame(width: SidebarMetrics.rowButton)
                        .accessibilityHidden(true)
                }
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
        .padding(.leading, rowIndent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(WorkspaceDraftRows.accessibilityLabel))
        .accessibilityValue(Text(isCreating ? "Creating" : ""))
        .accessibilityCustomContent(Text("Project"), Text(trailingRepo?.name ?? ""), importance: .high)
        .help(isCreating ? "Creating this workspace" : "A workspace not created yet")
    }
}
