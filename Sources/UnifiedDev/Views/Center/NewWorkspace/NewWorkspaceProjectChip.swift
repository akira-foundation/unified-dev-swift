import SwiftUI
import Core

struct NewWorkspaceProjectChip: View {
    var repo: Repo
    var onPick: @MainActor (RepoID) -> Void

    @Environment(AppModel.self) private var app

    @State private var isChoosing = false

    private var sections: [ProjectPickerSection] {
        ProjectPickerSections.build(repos: app.repos, activity: app.projectActivity)
    }

    var body: some View {
        let sections = self.sections
        let offersAChoice = ProjectPickerSections.offersAChoice(sections)

        return Button {
            isChoosing = true
        } label: {
            ComposerControlLabel(
                text: repo.name,
                tint: Palette.textPrimary,
                isActive: isChoosing,
                showsMenuIndicator: offersAChoice
            ) {
                mark(of: repo)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .disabled(!offersAChoice)
        .help("Choose the project")
        .accessibilityLabel("Project")
        .accessibilityValue(repo.name)
        .popover(isPresented: $isChoosing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    header(section.title)
                    ForEach(section.projects) { candidate in
                        row(of: candidate)
                    }
                }
            }
            .padding(Metrics.spacingSmall)
            .frame(minWidth: 200)
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(Typo.caption)
            .foregroundStyle(Palette.textTertiary)
            .padding(.horizontal, Metrics.spacing)
            .padding(.top, Metrics.spacingWide)
            .padding(.bottom, Metrics.spacingTight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(of candidate: Repo) -> some View {
        Button {
            isChoosing = false
            onPick(candidate.id)
        } label: {
            Label {
                HStack(spacing: Metrics.spacing) {
                    Text(candidate.name)
                    if candidate.hidden {
                        Text("hidden")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
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

    @ViewBuilder
    private func mark(of project: Repo) -> some View {
        if let image = RepoIconImage.of(project, size: Metrics.repoIconSmall) {
            Image(nsImage: image).renderingMode(.original)
        } else {
            Image(systemName: "folder")
        }
    }
}
