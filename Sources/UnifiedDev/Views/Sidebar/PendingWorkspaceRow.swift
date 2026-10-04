import SwiftUI
import Core

struct PendingWorkspaceRow: View {
    var pending: PendingWorkspace
    var projectName: String
    var trailingRepo: Repo?

    @Environment(\.sidebarRowIndent) private var rowIndent

    var body: some View {
        Label {
            HStack(spacing: Metrics.spacing) {
                Text(pending.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Palette.textSecondary)

                Spacer(minLength: 0)

                if let trailingRepo {
                    RepoIcon(repo: trailingRepo, size: Metrics.repoIconSmall)
                        .frame(width: SidebarMetrics.rowButton)
                        .accessibilityHidden(true)
                }
            }
        } icon: {
            WorkspaceStatusGlyph(status: .settingUp)
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, rowIndent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(pending.name))
        .accessibilityValue(Text("Creating"))
        .accessibilityCustomContent(Text("Project"), Text(projectName), importance: .high)
        .help("Creating this workspace")
    }
}
