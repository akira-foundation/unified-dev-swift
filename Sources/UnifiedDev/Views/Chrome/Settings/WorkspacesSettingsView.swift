import SwiftUI
import Core

struct WorkspacesSettingsView: View {
    @AppStorage("confirmBeforeArchiving") private var confirmBeforeArchiving = true
    @State private var namesWorkspaces = WorkspaceNamingPreferences().isEnabled
    @State private var deletesBranchOnArchive = GlobalWorkspaceSettings.deleteBranchOnArchive()
    @State private var archivesOnMerge = GlobalWorkspaceSettings.archiveOnMerge()

    var body: some View {
        Form {
            Section("New workspaces") {
                Toggle(isOn: $namesWorkspaces) {
                    Text("Name workspaces automatically")
                    Text("Claude uses your first message to suggest a name, without accessing your code.")
                }
                .onChange(of: namesWorkspaces) { _, value in
                    WorkspaceNamingPreferences().isEnabled = value
                }

                SettingsRow("Location") {
                    VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                        HStack(spacing: Metrics.gutter) {
                            Text((WorkspaceManager.workspacesRoot.path as NSString).abbreviatingWithTildeInPath)
                                .font(Typo.codeSmall)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                                .help(WorkspaceManager.workspacesRoot.path)
                            Spacer(minLength: 0)
                            Button("Reveal in Finder") {
                                Reveal.inFinder(WorkspaceManager.workspacesRoot.path)
                            }
                        }
                        DisclosureGroup("Folder details") {
                            Text(WorkspacesRoot.note(for: WorkspaceManager.workspacesRoot))
                                .settingsFootnote()
                        }
                    }
                }
            }

            Section("Archiving") {
                Toggle("Confirm before archiving", isOn: $confirmBeforeArchiving)

                Toggle(isOn: $deletesBranchOnArchive) {
                    Text("Delete the branch when a workspace is archived")
                    Text("The default for every project. A project's own settings override it.")
                }
                .onChange(of: deletesBranchOnArchive) { _, value in
                    do {
                        try GlobalWorkspaceSettings.setDeleteBranchOnArchive(value)
                    } catch {
                        deletesBranchOnArchive = GlobalWorkspaceSettings.deleteBranchOnArchive()
                    }
                }

                Toggle(isOn: $archivesOnMerge) {
                    Text("Archive a workspace when its pull request merges")
                    Text("The default for every project. A project's own settings override it.")
                }
                .onChange(of: archivesOnMerge) { _, value in
                    do {
                        try GlobalWorkspaceSettings.setArchiveOnMerge(value)
                    } catch {
                        archivesOnMerge = GlobalWorkspaceSettings.archiveOnMerge()
                    }
                }
            }

            ArchiveRetentionSettingsSection()

            MergeMethodSettingsSection()
        }
        .settingsForm()
    }
}
