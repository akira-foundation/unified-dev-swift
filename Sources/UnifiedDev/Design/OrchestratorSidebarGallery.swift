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

    private static let quietLead = WorkspaceID("quiet-lead")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RepoHeaderRow(repo: Self.repo, hasUnreadWork: true, workspaceCount: 6, onCreateWorkspace: { _ in })
                .frame(height: 32)
            ForEach(Self.rows, id: \.id) { row($0) }
        }
        .frame(width: 260, alignment: .topLeading)
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .environment(app)
    }

    private static let rows = [
        workspace("Orchestrator", id: lead, pinned: true, orchestrator: true),
        workspace("release notes", parent: lead, changed: true),
        workspace("sidebar order", parent: lead, unread: true),
        workspace("Quiet orchestrator", id: quietLead, orchestrator: true),
        workspace("no mark here", parent: quietLead, changed: true),
        workspace("nor here", parent: quietLead),
        workspace("pinned by hand", pinned: true),
        workspace("plain work", changed: true),
        workspace("unread work", unread: true),
    ]

    private func row(_ workspace: Workspace) -> some View {
        let isChild = SidebarReorder.isOrchestratorChild(workspace, among: Self.rows)
        let foldsMarkColumn = SidebarMarkPolicy.foldsMarkColumn(
            of: workspace,
            among: Self.rows,
            drawn: Set(Self.rows.map(\.id))
        ) { WorkspaceStatus.resolve(workspace: $0, isRunning: false, pullRequest: nil) }
        return WorkspaceRow(
            workspace: workspace,
            isRunning: false,
            foldsMarkColumn: foldsMarkColumn,
            renaming: $renaming,
            onArchive: { _ in },
            archiveRequest: .constant(nil),
            menuArchiveRequest: .constant(nil)
        )
        .padding(
            .leading,
            SidebarMetrics.rowIndent
                + (isChild ? SidebarMetrics.orchestratorChildIndent(foldsMarkColumn: foldsMarkColumn) : 0)
        )
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
