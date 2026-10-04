import SwiftUI
import Core

struct StartProjectLanding: View {
    var recent: [String]
    var repos: [Repo]
    var home: String
    var onNewProject: () -> Void
    var onClone: () -> Void
    var onOpen: () -> Void
    var onPick: (String) -> Void

    private static let listMinHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            actions
            folders
        }
    }

    private var actions: some View {
        HStack(spacing: Metrics.spacing) {
            Button("Open\u{2026}", action: onOpen)
            Button("Clone\u{2026}", action: onClone)
            Button("New Project", action: onNewProject)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.bottom, Metrics.gutter)
    }

    @ViewBuilder
    private var folders: some View {
        if recent.isEmpty {
            Text("No folders opened yet. Point at one, clone one, or make one.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, minHeight: Self.listMinHeight)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, Metrics.gutter)
        } else {
            ScrollView {
                LazyVStack(spacing: Metrics.spacingSmall) {
                    ForEach(recent, id: \.self) { path in
                        row(path)
                    }
                }
                .padding(Metrics.spacingSmall)
            }
            .frame(minHeight: Self.listMinHeight)
            .background(
                Palette.hover,
                in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
            )
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.gutter)
        }
    }

    private func row(_ path: String) -> some View {
        let project = StartProjectPick.project(at: path, repos: repos)
        return Button {
            onPick(path)
        } label: {
            HStack(spacing: Metrics.spacing) {
                tile(project)

                VStack(alignment: .leading, spacing: 0) {
                    Text(project?.name ?? (path as NSString).lastPathComponent)
                        .font(Typo.bodyEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                    Text(NewProjectPlan.display(path, home: home))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.spacing)
            .padding(.vertical, Metrics.spacingSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(
                RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(project?.name ?? (path as NSString).lastPathComponent)
        .accessibilityValue(project == nil ? "Not a project yet" : "Project")
    }

    @ViewBuilder
    private func tile(_ project: Repo?) -> some View {
        if let project {
            RepoIcon(repo: project)
        } else {
            Image(systemName: "folder")
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: Metrics.repoIcon, height: Metrics.repoIcon)
                .accessibilityHidden(true)
        }
    }
}
