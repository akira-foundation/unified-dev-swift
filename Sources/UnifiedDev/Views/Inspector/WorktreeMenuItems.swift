import SwiftUI
import Core

struct WorktreeMenuItems: View {
    var workspace: Workspace
    var pullRequest: PullRequest?

    var body: some View {
        Button("Copy Branch Name") { Clipboard.copy(workspace.branch) }
        Button("Reveal Worktree in Finder") { Reveal.inFinder(workspace.path) }
        OpenInItems(target: .folder(workspace.path), noun: "Worktree")

        if let pullRequest {
            Divider()
            Button("Open Pull Request") { GitHubBridge.open(pullRequest.url) }
            if let url = URL(string: pullRequest.url) {
                ShareLink(item: url) { Text("Share pull request") }
            }
        }
    }
}
