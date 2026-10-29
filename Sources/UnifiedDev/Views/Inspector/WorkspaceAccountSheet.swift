import SwiftUI
import Core

struct WorkspaceAccountSheet: View {
    var workspace: Workspace

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                AgentAccountSection(
                    level: .workspace,
                    target: AccountScope(workspaceID: workspace.id, repoID: workspace.repoID)
                )
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Metrics.gutter)
        }
        .frame(width: 440)
        .navigationTitle("Account for \(workspace.name)")
    }
}
