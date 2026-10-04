import SwiftUI
import Core

struct StartProjectSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var isNaming = false

    var body: some View {
        if isNaming {
            StartProjectView()
        } else {
            StartProjectLanding(
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
        guard let first = app.workspaces.first(where: { $0.repoID == repo.id }) else {
            return app.openDraft(in: repo)
        }
        app.selection = .workspace(first.id)
    }
}
