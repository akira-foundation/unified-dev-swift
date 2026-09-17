import SwiftUI
import Core

struct SidebarIndentGallery: View {
    var app: AppModel

    @State private var renaming: WorkspaceID?

    private static let repo = Repo(
        id: RepoID("unifieddev"), name: "unifieddev", path: "/Users/x/dev/unifieddev"
    )

    private static let now = Date(timeIntervalSince1970: 1_750_000_000)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Sidebar indents")
                .font(Typo.title)
            Text("Every name under a project starts on the project's own name.")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)

            HStack(alignment: .top, spacing: 24) {
                pane("A project with work in it") {
                    header(count: 3)
                    workspace(name: "sidebar name column", unread: true)
                    workspace(name: "checks that go quiet", changed: true)
                    crew
                    subagent
                    PendingWorkspaceRow(pending: PendingWorkspace(
                        id: WorkspaceID("pending"), repoID: Self.repo.id, name: "one door out"
                    ))
                    .frame(height: 32)
                }

                pane("A project with none") {
                    header(count: 0)
                    SidebarEmptyNoticeRow(isFiltered: false)
                        .frame(height: 32)
                    SidebarEmptyNoticeRow(isFiltered: true)
                        .frame(height: 32)
                }
            }
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.windowBackground)
        .environment(app)
    }

    private func pane(
        _ title: String, @ViewBuilder rows: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                rows()
            }
            .frame(width: 260, alignment: .leading)
            .background(Palette.surface)
            .overlay(alignment: .leading) { columns }
        }
    }

    private var columns: some View {
        ZStack(alignment: .leading) {
            rule(at: SidebarMetrics.rowIndent, isFaint: true)
            rule(at: SidebarMetrics.rowIndent + SidebarMetrics.markColumn, isFaint: true)
            rule(at: SidebarMetrics.nameColumn, isFaint: false)
        }
        .allowsHitTesting(false)
    }

    private func rule(at x: CGFloat, isFaint: Bool) -> some View {
        Rectangle()
            .fill(Palette.accentFill.opacity(isFaint ? 0.25 : 0.7))
            .frame(width: 1)
            .offset(x: x)
    }

    private func header(count: Int) -> some View {
        RepoHeaderRow(
            repo: Self.repo,
            hasUnreadWork: count > 0,
            workspaceCount: count,
            onCreateWorkspace: { _ in }
        )
        .frame(height: 32)
    }

    private func workspace(name: String, unread: Bool = false, changed: Bool = false) -> some View {
        WorkspaceRow(
            workspace: Workspace(
                repoID: Self.repo.id,
                name: name,
                branch: name.replacingOccurrences(of: " ", with: "-"),
                path: "/tmp/worktree",
                baseBranch: "main",
                createdAt: Self.now,
                lastActivityAt: Self.now,
                additions: changed ? 41 : 0,
                deletions: changed ? 12 : 0,
                changedFiles: changed ? 4 : 0,
                unread: unread
            ),
            isRunning: false,
            renaming: $renaming,
            onArchive: { _ in },
            archiveRequest: .constant(nil),
            menuArchiveRequest: .constant(nil)
        )
        .padding(.leading, SidebarMetrics.rowIndent)
        .frame(height: 32)
    }

    private var crew: some View {
        CrewSidebarRow(row: CrewRow(Session(
            workspaceID: WorkspaceID("w1"),
            parentSessionID: SessionID("s0"),
            title: "cascade-read",
            createdAt: Self.now,
            updatedAt: Self.now
        )))
        .frame(height: 32)
    }

    private var subagent: some View {
        SubagentSidebarRow(row: SubagentRow(Subagent(
            id: SubagentID("1"),
            description: "Find every row under a project",
            type: "Explore",
            state: .completed,
            summary: "five of them",
            outputFile: "/x",
            elapsedSeconds: 14
        )))
        .frame(height: 32)
    }
}

extension Gallery {
    static let sidebarIndent = Gallery(
        name: "sidebar-indent",
        title: "Sidebar indents",
        size: CGSize(width: 620, height: 320),
        needsFocus: false,
        view: { app in AnyView(SidebarIndentGallery(app: app)) }
    )
}
