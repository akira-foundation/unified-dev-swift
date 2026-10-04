import AppKit
import SwiftUI
import Core

struct StartProjectLanding: View {
    var onNewProject: () -> Void
    var onOpen: (String) -> Void
    var onPick: (Repo) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private static let markSize: CGFloat = 96
    private static let width: CGFloat = 560
    private static let listMinHeight: CGFloat = 220
    private static let closeSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            plinth
            actions
            projects
        }
        .frame(width: Self.width)
        .presentationBackground(Palette.surface)
        .overlay(alignment: .topLeading) { closeButton }
    }

    private var plinth: some View {
        VStack(spacing: Metrics.spacing) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .accessibilityHidden(true)

            Text(verbatim: "Unified Dev")
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)

            Text(versionLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.top, Metrics.gutter * 2)
        .padding(.bottom, Metrics.gutter)
    }

    private var actions: some View {
        HStack(spacing: Metrics.spacing) {
            Button("Open\u{2026}", action: openFolder)
            Button("New Project", action: onNewProject)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.bottom, Metrics.gutter)
    }

    @ViewBuilder
    private var projects: some View {
        if app.repos.isEmpty {
            Text("No projects yet. Point at a folder, or make one.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, minHeight: Self.listMinHeight)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, Metrics.gutter)
        } else {
            ScrollView {
                LazyVStack(spacing: Metrics.spacingSmall) {
                    ForEach(app.repos) { repo in
                        row(repo)
                    }
                }
                .padding(Metrics.spacingSmall)
            }
            .frame(minHeight: Self.listMinHeight)
            .background(Palette.hover, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.gutter)
        }
    }

    private func row(_ repo: Repo) -> some View {
        Button {
            onPick(repo)
        } label: {
            HStack(spacing: Metrics.spacing) {
                RepoIcon(repo: repo)

                VStack(alignment: .leading, spacing: 0) {
                    Text(repo.name)
                        .font(Typo.bodyEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                    Text(NewProjectPlan.display(repo.path, home: home))
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
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(repo.name)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(Typo.label)
                .foregroundStyle(Palette.textPrimary)
                .frame(width: Self.closeSize, height: Self.closeSize)
                .background(Palette.hover, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(Metrics.spacing)
        .help("Close")
        .accessibilityLabel("Close")
    }

    private var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    private var versionLine: String {
        BuildIdentity.read(from: .main).line(built: BuildTimestamp.read(from: .main))
    }

    private func openFolder() {
        Task {
            guard let chosen = await ProjectFolderPicker.chooseTarget(startingAt: home) else { return }
            onOpen(chosen)
        }
    }
}
