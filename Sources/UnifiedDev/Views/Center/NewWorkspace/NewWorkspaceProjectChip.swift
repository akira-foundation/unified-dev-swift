import SwiftUI
import Core

struct NewWorkspaceProjectChip: View {
    var repo: Repo
    var onPick: @MainActor (RepoID) -> Void

    @Environment(AppModel.self) private var app

    @State private var isChoosing = false

    private var offered: [Repo] {
        ProjectMenuGroup.grouped(ProjectVisibility.listed(app.repos, showingHidden: false)).flatMap(\.repos)
    }

    var body: some View {
        Button {
            isChoosing = true
        } label: {
            ComposerControlLabel(
                text: repo.name,
                tint: Palette.textPrimary,
                isActive: isChoosing,
                showsMenuIndicator: offered.count > 1
            ) {
                mark(of: repo)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .disabled(offered.count < 2)
        .help("Choose the project")
        .accessibilityLabel("Project")
        .accessibilityValue(repo.name)
        .popover(isPresented: $isChoosing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(offered) { candidate in
                    Button {
                        isChoosing = false
                        onPick(candidate.id)
                    } label: {
                        Label {
                            Text(candidate.name)
                        } icon: {
                            mark(of: candidate)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.spacing)
                        .frame(height: Metrics.rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(candidate.id == repo.id ? .isSelected : [])
                }
            }
            .padding(Metrics.spacingSmall)
            .frame(minWidth: 200)
        }
    }

    @ViewBuilder
    private func mark(of project: Repo) -> some View {
        if let image = RepoIconImage.of(project, size: Metrics.repoIconSmall) {
            Image(nsImage: image).renderingMode(.original)
        } else {
            Image(systemName: "folder")
        }
    }
}
