import SwiftUI
import Core

struct NewWorkspaceProjectChip: View {
    var repo: Repo
    var onPick: @MainActor (RepoID) -> Void

    @Environment(AppModel.self) private var app

    private var offered: [Repo] {
        ProjectMenuGroup.grouped(ProjectVisibility.listed(app.repos, showingHidden: false)).flatMap(\.repos)
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
                mark
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(offered.count < 2)
        .help("Choose the project")
        .accessibilityLabel("Project")
        .accessibilityValue(repo.name)
    }

    @ViewBuilder
    private var mark: some View {
        if let image = RepoIconImage.of(repo, size: Metrics.repoIconSmall) {
            Image(nsImage: image).renderingMode(.original)
        } else {
            Image(systemName: "folder")
        }
    }
}
