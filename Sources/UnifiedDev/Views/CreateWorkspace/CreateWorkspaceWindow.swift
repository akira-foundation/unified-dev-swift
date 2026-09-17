import SwiftUI
import Core

struct CreateWorkspaceWindow: Scene {
    let model: AppModel

    static let id = "create-workspace"

    var body: some Scene {
        WindowGroup("New Workspace", id: Self.id, for: RepoID.self) { $repoID in
            CreateWorkspaceWindowContent(repoID: repoID)
                .environment(model)
                .windowRole(.utility)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}

private struct CreateWorkspaceWindowContent: View {
    let repoID: RepoID?

    @Environment(AppModel.self) private var app

    var body: some View {
        CreateWorkspaceView(initialRepo: app.repos.first { $0.id == repoID })
    }
}

@MainActor
@Observable
final class CreateWorkspaceOpening {
    static let shared = CreateWorkspaceOpening()

    private(set) var wantsPullRequest = false

    private init() {}

    func askForPullRequest() {
        wantsPullRequest = true
    }

    func consumePullRequestAsk() -> Bool {
        guard wantsPullRequest else { return false }
        wantsPullRequest = false
        return true
    }
}
