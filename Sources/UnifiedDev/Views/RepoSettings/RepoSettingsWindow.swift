import SwiftUI
import Core

extension Notification.Name {
    static let unifieddevOpenRepoSettings = Notification.Name("unifieddevOpenRepoSettings")
}

struct RepoSettingsWindow: Scene {
    let model: AppModel

    static let id = "repo-settings"

    var body: some Scene {
        WindowGroup(id: Self.id, for: Repo.ID.self) { $repoID in
            RepoSettingsWindowContent(repoID: repoID)
                .environment(model)
                .windowRole(.utility)
        }
        .defaultSize(width: RepoSettingsView.idealSize.width, height: RepoSettingsView.idealSize.height)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
    }
}

private struct RepoSettingsWindowContent: View {
    let repoID: Repo.ID?

    @Environment(AppModel.self) private var app

    var body: some View {
        if let repo = app.repos.first(where: { $0.id == repoID }) {
            RepoSettingsView(repo: repo)
                .id(repo.id)
        } else {
            ContentUnavailableView(
                "This project is no longer in Unified Dev",
                systemImage: "folder.badge.questionmark",
                description: Text("It was removed, or this window was restored from a launch before it was.")
            )
            .frame(
                minWidth: RepoSettingsView.minimumSize.width,
                minHeight: RepoSettingsView.minimumSize.height
            )
            .background(Palette.windowBackground)
        }
    }
}

struct RepoSettingsButton: View {
    let repo: Repo
    var isHighlighted: Bool = false

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: RepoSettingsWindow.id, value: repo.id)
        } label: {
            Label("Settings for \(repo.name)", systemImage: "gearshape")
                .labelStyle(.iconOnly)
                .font(Typo.label)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .foregroundStyle(isHighlighted ? Palette.textPrimary : Palette.textSecondary)
        .help("Settings for \(repo.name)")
    }
}
