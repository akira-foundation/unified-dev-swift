import SwiftUI
import Core

#if DEBUG
struct OrchestratorSidebarGallery: View {
    var app: AppModel

    @State private var renaming: WorkspaceID?

    private static let repo = Repo(
        id: RepoID("unifieddev"), name: "unified-dev", path: "/Users/x/dev/unified-dev"
    )

    private static let now = Date(timeIntervalSince1970: 1_750_000_000)

    private static let lead = WorkspaceID("lead")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RepoHeaderRow(repo: Self.repo, hasUnreadWork: true, workspaceCount: 5, onCreateWorkspace: { _ in })
                .frame(height: 32)
            row(Self.workspace("Orchestrator", id: Self.lead, pinned: true, orchestrator: true))
            row(Self.workspace("release notes", parent: Self.lead, changed: true), isChild: true)
            row(Self.workspace("sidebar order", parent: Self.lead, unread: true), isChild: true)
            row(Self.workspace("pinned by hand", pinned: true))
            row(Self.workspace("plain work", changed: true))
        }
        .frame(width: 260, alignment: .topLeading)
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .environment(app)
    }

    private func row(_ workspace: Workspace, isChild: Bool = false) -> some View {
        WorkspaceRow(
            workspace: workspace,
            isRunning: false,
            renaming: $renaming,
            onArchive: { _ in },
            archiveRequest: .constant(nil),
            menuArchiveRequest: .constant(nil)
        )
        .padding(.leading, SidebarMetrics.rowIndent + (isChild ? SidebarMetrics.subagentIndent : 0))
        .frame(height: 32)
    }

    private static func workspace(
        _ name: String,
        id: WorkspaceID = .new(),
        parent: WorkspaceID? = nil,
        pinned: Bool = false,
        orchestrator: Bool = false,
        unread: Bool = false,
        changed: Bool = false
    ) -> Workspace {
        Workspace(
            id: id,
            repoID: repo.id,
            name: name,
            branch: name.replacingOccurrences(of: " ", with: "-"),
            path: "/tmp/worktree",
            baseBranch: "main",
            createdAt: now,
            lastActivityAt: now,
            additions: changed ? 41 : 0,
            deletions: changed ? 12 : 0,
            changedFiles: changed ? 4 : 0,
            unread: unread,
            pinned: pinned,
            origin: parent.map { .agent(parentWorkspaceID: $0, spawnToolUseID: "gallery") } ?? .user,
            isOrchestrator: orchestrator
        )
    }
}
#endif
