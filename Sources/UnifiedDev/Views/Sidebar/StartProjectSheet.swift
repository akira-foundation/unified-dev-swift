import SwiftUI
import Core

struct StartProjectSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ProjectVisibility.showsHiddenKey) private var showsHiddenProjects = false

    @State private var isNaming = false

    var body: some View {
        if isNaming {
            StartProjectView()
        } else {
            StartProjectLanding(
                repos: StartProjectPick.offered(app.repos, showingHidden: showsHiddenProjects),
                onNewProject: { isNaming = true },
                onOpen: add(at:),
                onPick: open(_:)
            )
        }
    }

    private func add(at path: String) {
        dismiss()
        Task { await app.addRepository(at: path) }
    }

    private func open(_ repo: Repo) {
        dismiss()
        let opened = StartProjectPick.opens(repo: repo, workspaces: app.workspaces) { _ in true }
        guard let opened else { return app.openDraft(in: repo) }
        app.selection = .workspace(opened)
    }
}
