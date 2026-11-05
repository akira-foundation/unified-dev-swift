import SwiftUI
import Core

struct ProjectMenuItems: View {
    var repo: Repo
    var onCreateWorkspace: (Repo) -> Void
    var onRename: () -> Void
    var onRemove: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow

    private var moveTargets: [Profile] {
        ProfileMove.targets(for: repo, among: app.profiles)
    }

    var body: some View {
        Button("New workspace") { onCreateWorkspace(repo) }
        Divider()
        Button("Rename", action: onRename)
        Button("Project settings…") {
            openWindow(id: RepoSettingsWindow.id, value: repo.id)
        }
        Button("Reveal in Finder") { Reveal.inFinder(repo.path) }
        Button(repo.hidden ? "Unhide project" : "Hide project") {
            Task { await app.toggleHidden(repo) }
        }
        if !moveTargets.isEmpty {
            Menu("Move to Profile") {
                ProfileMoveTargets(targets: moveTargets) { profile in
                    Task { await app.moveProject(repo.id, to: profile) }
                }
            }
        }
        Divider()
        Button("Remove project", role: .destructive, action: onRemove)
    }
}
