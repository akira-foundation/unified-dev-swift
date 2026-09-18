import SwiftUI
import Core

struct NewWorkspaceProjectChip: View {
    var repo: Repo
    var onPick: @MainActor (RepoID) -> Void

    @Environment(AppModel.self) private var app

    private var offered: [Repo] {
        ProjectMenuGroup.grouped(ProjectVisibility.listed(app.repos, showingHidden: false)).first?.repos ?? []
    }

    var body: some View {
        Menu {
            ForEach(offered) { candidate in
                Button {
                    onPick(candidate.id)
                } label: {
                    Label {
                        Text(candidate.name)
                    } icon: {
                        if let mark = RepoIconImage.of(candidate) {
                            Image(nsImage: mark).renderingMode(.original)
                        }
                    }
                }
            }
        } label: {
            ComposerControlLabel(
                text: repo.name,
                tint: Palette.textPrimary,
                showsMenuIndicator: offered.count > 1
            ) {
                RepoIcon(repo: repo, size: Metrics.repoIconSmall)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(offered.count < 2)
        .help("Choose the project")
        .accessibilityLabel("Project")
        .accessibilityValue(repo.name)
    }
}
