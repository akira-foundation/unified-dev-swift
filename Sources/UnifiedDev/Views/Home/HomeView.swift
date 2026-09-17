import SwiftUI
import Core

struct HomeView: View {
    @Environment(AppModel.self) private var app

    @State private var archived: [Workspace] = []
    @State private var listing = HomeListing.empty
    @State private var selected: WorkspaceID?
    @State private var now = Date()
    @State private var hovered: WorkspaceID?
    @State private var renaming: WorkspaceID?
    @State private var deleting: ArchiveDeletion?

    @State private var footprints = ArchiveCleanup(footprints: [])
    @State private var databaseSize: DatabaseSize?
    @State private var measuredRevision: Int?
    @State private var isCompacting = false

    @State private var arrival = RowArrival<WorkspaceID>()

    private var filter: HomeFilter { app.homeFilter }

    var body: some View {
        @Bindable var app = app

        return VStack(spacing: 0) {
            queryHeader

            content

            if hasAnyWorkspace, !summary.isEmpty {
                HomeStatusBar(summary: summary, compaction: compaction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusedValue(\.focusedWorkspaceRow, focusedRow)
        .focusedValue(\.homeScopeCounts, listing.counts)
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevRenameWorkspace)) { note in
            guard let raw = note.userInfo?[Notification.unifieddevWorkspaceIDKey] as? String,
                  let row = row(for: WorkspaceID(raw)), !row.isArchived else { return }
            renaming = row.id
        }
        .task(id: app.archivedRevision) {
            archived = await app.archivedWorkspaces()
            await loadFootprints()
        }
        .task { await keepAgesCurrent() }
        .confirmation($deleting) { deletion in
            Confirmation(
                title: deletion.title,
                message: deletion.message,
                confirmLabel: deletion.confirmLabel,
                cancelLabel: deletion.cancelLabel,
                tone: .destructive
            )
        } onConfirm: { deletion in
            Task { await delete(deletion) }
        }
        .onChange(of: app.workspaces, initial: true) { _, _ in rebuild() }
        .onChange(of: app.repos) { _, _ in rebuild() }
        .onChange(of: archived) { _, _ in rebuild() }
        .onChange(of: app.runningWorkspaceIDs) { _, _ in rebuild() }
        .onChange(of: app.waitingWorkspaceIDs) { _, _ in rebuild() }
        .onChange(of: app.homeFilter) { old, new in
            rebuild(rescoped: true)
            if old.scope != new.scope { Task { await loadFootprints() } }
            if old.query != new.query { app.searchTranscripts(new.query) }
        }
        .onChange(of: app.transcriptResults) { _, _ in rebuild(rescoped: true) }
        .onAppear { app.searchTranscripts(app.homeFilter.query) }
    }

    @ViewBuilder
    private var content: some View {
        if let empty = emptyState {
            empty
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    @ViewBuilder
    private var queryHeader: some View {
        if hasAnyWorkspace, listing.isSearching {
            HStack(spacing: Metrics.spacingSmall) {
                Image(systemName: "magnifyingglass")
                    .font(Typo.micro)
                    .imageScale(.small)

                Text(filter.query)
                    .font(Typo.caption)
                    .lineLimit(1)

                Spacer(minLength: Metrics.spacing)

                Button {
                    app.homeFilter.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Typo.micro)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .help("Clear the search")
                .accessibilityLabel("Clear the search")
            }
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, HomeMetrics.gutter)
            .frame(height: Metrics.barHeight)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Searching for \(filter.query)")
        }
    }

    private var list: some View {
        List(selection: $selected) {
            ForEach(listing.groups) { group in
                Section {
                    HomeGroupHeading(title: group.title)
                        .listRowInsets(Self.rowInsets)
                        .listRowBackground(Color.clear)
                        .selectionDisabled()

                    ForEach(group.rows) { row in
                        HomeListRow(
                            row: row,
                            isRunning: app.isRunning(row.workspace),
                            isAwaitingPermission: app.isAwaitingPermission(row.workspace),
                            now: now,
                            isRenaming: renaming == row.id,
                            onCommitRename: { commitRename(row, to: $0) },
                            onCancelRename: { closeField(of: row) }
                        )
                        .arrivingRow(arrival.isArriving(row.id))
                        .tag(row.id)
                        .simultaneousGesture(TapGesture().onEnded { open(row) })
                        .listRowInsets(Self.rowInsets)
                        .onHoverChange { hovered = $0 ? row.id : (hovered == row.id ? nil : hovered) }
                        .listRowBackground(
                            HomeRowBackground(
                                isSelected: selected == row.id,
                                isHovered: hovered == row.id
                            )
                        )
                        .contextMenu {
                            HomeRowMenu(row: row, onRename: { renaming = $0 }, onDelete: askToDelete)
                        }
                    }
                }
            }

            transcriptResults
        }
        .listStyle(.inset)
        .settlesArrivals($arrival)
        .scrollContentBackground(.hidden)
        .onKeyPress(.return) {
            guard let selected, let row = row(for: selected) else { return .ignored }
            open(row)
            return .handled
        }
        .onDeleteCommand {
            guard let selected, let row = row(for: selected) else { return }
            if row.isArchived {
                askToDelete(row.workspace)
            } else {
                Task { await app.archive(row.workspace) }
            }
        }
    }

    @ViewBuilder
    private var transcriptResults: some View {
        if !listing.transcripts.isEmpty {
            Section {
                ForEach(listing.transcripts) { result in
                    TranscriptResultRow(
                        result: result,
                        workspace: workspace(result.workspaceID),
                        repo: workspace(result.workspaceID).flatMap { app.repo(for: $0) },
                        isArchived: archived.contains { $0.id == result.workspaceID },
                        openWorkspace: { openTranscript(result) },
                        openMatch: { match in Task { await app.open(match) } }
                    )
                    .listRowInsets(Self.rowInsets)
                    .listRowBackground(Color.clear)
                    .selectionDisabled()
                }
            } header: {
                Text(HomeList.transcriptHeading(listing.transcripts))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.leading, Self.rowInsets.leading)
            }
        }

        if listing.isSearching, app.isTranscriptIndexIncomplete {
            Label("Still indexing older transcripts", systemImage: "clock")
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .listRowInsets(Self.rowInsets)
                .listRowBackground(Color.clear)
                .selectionDisabled()
        }
    }

    private static let rowInsets = EdgeInsets(
        top: 0, leading: HomeMetrics.rowInset, bottom: 0, trailing: HomeMetrics.rowInset
    )

    private var summary: String {
        HomeList.summary(
            listing: listing,
            filter: filter,
            projects: app.repos.count,
            database: databaseSize
        )
    }

    private var compaction: HomeStatusBar.Compaction? {
        guard filter.scope.showsFootprints, let size = databaseSize, size.isWorthCompacting else {
            return nil
        }
        return HomeStatusBar.Compaction(help: size.compactionHelp, isRunning: isCompacting) {
            Task { await compact() }
        }
    }

    private var hasAnyWorkspace: Bool {
        !app.workspaces.isEmpty || !archived.isEmpty
    }

    @ViewBuilder
    private var emptyState: (some View)? {
        if let state = HomeEmptyState.resolve(
            hasProjects: !app.repos.isEmpty,
            hasAnyWorkspace: hasAnyWorkspace,
            isListEmpty: listing.isEmpty,
            query: filter.query,
            scope: filter.scope,
            hasProjectFilter: !filter.projects.isEmpty,
            projectPhrase: projectPhrase
        ) {
            ContentUnavailableView {
                Label(state.title, systemImage: state.symbol)
            } description: {
                Text(state.message)
            } actions: {
                action(for: state)
            }
        }
    }

    @ViewBuilder
    private func action(for state: HomeEmptyState) -> some View {
        switch state {
        case .noProjects:
            Button(state.actionTitle, systemImage: "plus", action: startProject)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
        case .noWorkspaces:
            Button(state.actionTitle, systemImage: "plus") { requestWorkspace(in: nil) }
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
        case .noMatch:
            Button(state.actionTitle) { app.homeFilter.query = "" }
        case .noneInChosenProjects:
            Button(state.actionTitle) { app.homeFilter.projects = [] }
        case .emptyScope:
            Button(state.actionTitle) { app.homeFilter.scope = .all }
        }
    }

    private var projectPhrase: String {
        filter.projects.count == 1
            ? (app.repos.first { filter.projects.contains($0.id) }?.name ?? "that project")
            : "\(filter.projects.count) projects"
    }

    private func rebuild(rescoped: Bool = false) {
        let stamp = Date()
        now = stamp
        listing = HomeList.build(
            repos: app.repos,
            workspaces: app.workspaces,
            archived: archived,
            transcripts: app.transcriptResults,
            filter: filter,
            activity: HomeActivity(
                running: app.runningWorkspaceIDs, waiting: app.waitingWorkspaceIDs
            ),
            footprints: footprints,
            now: stamp
        )
        let ids = listing.groups.flatMap { $0.rows.map(\.id) }
        if rescoped {
            arrival.adopt(ids)
        } else {
            arrival.absorb(ids)
        }
    }

    private func loadFootprints() async {
        guard filter.scope.showsFootprints else { return }
        let revision = app.archivedRevision
        guard measuredRevision != revision else { return }
        footprints = await app.archiveCleanup()
        databaseSize = await app.databaseSize()
        measuredRevision = revision
        rebuild()
    }

    private func keepAgesCurrent() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            rebuild()
        }
    }

    private func row(for id: WorkspaceID) -> HomeRow? {
        for group in listing.groups {
            if let match = group.rows.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    private var focusedRow: FocusedWorkspaceRow? {
        guard let selected, let row = row(for: selected) else { return nil }
        return FocusedWorkspaceRow(workspace: row.workspace, isArchived: row.isArchived)
    }

    private func askToDelete(_ workspace: Workspace) {
        Task {
            let cleanup = await app.archiveCleanup()
            guard let footprint = cleanup.footprints.first(where: { $0.id == workspace.id }) else {
                return
            }
            deleting = ArchiveDeletion([footprint])
        }
    }

    private func delete(_ deletion: ArchiveDeletion) async {
        let outcome = await app.deleteArchived(deletion.footprints.map(\.id))
        if let sentence = outcome.sentence {
            app.alert = AppAlert(title: "Nothing was deleted", message: sentence)
        }
    }

    private func compact() async {
        isCompacting = true
        await app.compactDatabase()
        databaseSize = await app.databaseSize()
        isCompacting = false
    }

    private func open(_ row: HomeRow) {
        if row.isArchived {
            app.openArchived(row.workspace)
        } else {
            app.selection = .workspace(row.id)
        }
    }

    private func workspace(_ id: WorkspaceID) -> Workspace? {
        app.workspaces.first { $0.id == id } ?? archived.first { $0.id == id }
    }

    private func openTranscript(_ result: TranscriptWorkspaceMatches) {
        guard let workspace = workspace(result.workspaceID) else { return }
        if workspace.state == .active {
            app.selection = .workspace(workspace.id)
        } else {
            app.openArchived(workspace)
        }
    }

    private func requestWorkspace(in repo: Repo?) {
        NotificationCenter.default.post(name: .udNewWorkspace, object: repo)
    }

    private func startProject() {
        NotificationCenter.default.post(name: .udNewProject, object: nil)
    }

    private func commitRename(_ row: HomeRow, to newName: String) {
        closeField(of: row)
        Task { await app.rename(row.workspace, to: newName) }
    }

    private func closeField(of row: HomeRow) {
        if renaming == row.id { renaming = nil }
    }
}
