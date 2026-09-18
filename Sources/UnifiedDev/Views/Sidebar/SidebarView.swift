import SwiftUI
import Core

struct SidebarView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager

    @State private var renaming: WorkspaceID?
    @State private var filter: SidebarFilter = .all

    @AppStorage(ProjectVisibility.showsHiddenKey) private var showsHiddenProjects = false

    @State private var listSelection: SidebarSelection?
    @State private var archivePresentation = SidebarArchivePresentation()

    @State private var groups: [SidebarRepoGroup] = []

    @State private var paneRows: [SidebarPaneRow] = []
    @State private var workspaceIdentities: Set<WorkspaceID> = []

    @State private var reorderNote: ReorderNote?
    @State private var stoppingCrew: PendingCrewStop?

    private struct ReorderNote: Equatable {
        var id = UUID()
        var sentence: String
    }

    @State private var hasSettled = false

    @State private var arrival = RowArrival<WorkspaceID>()

    var body: some View {
        List(selection: $listSelection) {
            Section {
                navRow(.home, title: "Home", icon: "house")
                askRow
            }

            SidebarProjectsHeader(onStartProject: startProject)
                .selectionDisabled()
                .listRowSeparator(.hidden)

            ForEach(paneRows) { row in
                switch row {
                case .project(let group):
                    RepoHeaderRow(
                        repo: group.repo,
                        hasUnreadWork: group.hasUnreadWork,
                        workspaceCount: group.workspaces.count,
                        onCreateWorkspace: presentCreate
                    )
                    .selectionDisabled()
                case .workspace(let workspace, let projectName):
                    workspaceRow(workspace, projectName: projectName)
                case .crew(let member, let workspaceID, _):
                    CrewSidebarRow(row: member)
                        .contextMenu {
                            Button("Stop Subagent") { askToStop(member, in: workspaceID) }
                        }
                        .moveDisabled(true)
                        .tag(SidebarSelection.crew(workspaceID, member.id))
                case .subagent(let subagent, let workspaceID, _):
                    SubagentSidebarRow(row: subagent)
                        .selectionDisabled(!subagent.opensOutput)
                        .moveDisabled(true)
                        .tag(SidebarSelection.subagent(workspaceID, subagent.id))
                case .pending(let pending):
                    PendingWorkspaceRow(pending: pending)
                        .arrivingRow(arrival.isArriving(pending.id))
                        .selectionDisabled()
                        .moveDisabled(true)

                case .notice:
                    SidebarEmptyNoticeRow(isFiltered: filter != .all)
                        .selectionDisabled()
                        .moveDisabled(true)

                case .draft(let repoID):
                    WorkspaceDraftRow(isCreating: app.drafts.isCreating(repoID))
                        .moveDisabled(true)
                        .contextMenu {
                            Button("Discard Draft") { app.discardDraft(repoID) }
                                .disabled(app.drafts.isCreating(repoID))
                        }
                        .tag(SidebarSelection.draft(repoID))
                }
            }
            .onMove(perform: move)
        }
        .listStyle(.sidebar)
        .environment(\.appearsActive, false)
        .scrollContentBackground(.hidden)
        .confirmation($stoppingCrew) { pending in
            Confirmation(
                title: "Stop \(pending.name)?",
                message: Self.crewStopMessage,
                confirmLabel: "Stop",
                cancelLabel: "Keep Working"
            )
        } onConfirm: { pending in
            Task { await stop(pending) }
        }
        .animation(foldMotion, value: foldedProjects)
        .animation(visibilityMotion, value: hiddenProjects)
        .animation(visibilityMotion, value: projectIdentities)
        .animation(workspaceMotion, value: workspaceIdentities)
        .animation(subagentMotion, value: subagentIdentities)
        .animation(subagentMotion, value: crewIdentities)
        .settlesArrivals($arrival)
        .task(id: reorderNote) {
            guard reorderNote != nil else { return }
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            reorderNote = nil
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarStatusBar(filter: $filter, note: reorderNote?.sentence)
        }
        .task(id: app.isLoaded) {
            hasSettled = false
            guard app.isLoaded else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            hasSettled = true
        }
        .onChange(of: app.repos, initial: true) { _, _ in regroup() }
        .onChange(of: app.workspaces) { _, _ in regroup() }
        .onChange(of: app.subagentRows) { _, _ in reflow() }
        .onChange(of: app.crewRows) { _, _ in reflow() }
        .onChange(of: app.pendingWorkspaces) { _, _ in regroup() }
        .onChange(of: app.shownDrafts) { _, _ in reflow() }
        .onChange(of: app.drafts.creatingWorkspaceIDs) { _, _ in reflow() }
        .onChange(of: filter) { _, _ in
            archivePresentation.cancel()
            regroup(rescoped: true)
        }
        .onAppear { SwitchProbe.attachSidebarSelection($listSelection) }
        .onDisappear {
            archivePresentation.cancel()
            SwitchProbe.attachSidebarSelection(nil)
        }
        .onChange(of: showsHiddenProjects) { _, _ in
            regroup(rescoped: !ProjectVisibilityMotion.filterToggle(reduceMotion: reduceMotion)
                .fadesArrivals)
        }
        .onChange(of: listSelection) { _, selected in
            if selected == nil { listSelection = app.selection }
        }
        .task(id: listSelection) {
            guard let target = listSelection, target != app.selection else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            commitSelection(target, replacing: app.selection)
        }
        .onDeleteCommand {
            guard let id = listSelection?.workspaceID,
                  let workspace = app.workspaces.first(where: { $0.id == id }) else { return }
            guard paneRows.contains(where: { row in
                if case .workspace(let shown, _) = row { return shown.id == workspace.id }
                return false
            }) else { return }
            archiveFromKeyboard(workspace)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevRenameWorkspace)) { note in
            guard let raw = note.userInfo?[Notification.unifieddevWorkspaceIDKey] as? String else {
                return
            }
            let id = WorkspaceID(raw)
            guard app.workspaces.contains(where: { $0.id == id }) else { return }
            renaming = id
        }
        .onChange(of: app.selection, initial: true) { _, target in
            renaming = nil
            listSelection = target
        }
        .onChange(of: undoManager, initial: true) { _, manager in
            app.undoManager = manager
        }
    }

    private var foldMotion: Animation? {
        guard !reduceMotion, hasSettled else { return nil }
        return Motion.pane
    }

    private var foldedProjects: [RepoID] {
        groups.filter(\.repo.collapsed).map(\.id)
    }

    private var projectIdentities: Set<RepoID> {
        Set(groups.map(\.id))
    }

    private var hiddenProjects: [RepoID] {
        groups.filter(\.repo.hidden).map(\.id)
    }

    private var visibilityMotion: Animation? {
        guard hasSettled,
              let seconds = ProjectVisibilityMotion
                  .hideGesture(showingHidden: showsHiddenProjects, reduceMotion: reduceMotion)
                  .seconds
        else { return nil }
        return .easeOut(duration: seconds)
    }

    private var subagentIdentities: [WorkspaceID: [SubagentID]] {
        app.subagentRows.mapValues { $0.map(\.id) }
    }

    private var crewIdentities: [WorkspaceID: [SessionID]] {
        app.crewRows.mapValues { $0.map(\.id) }
    }

    private var workspaceMotion: Animation? {
        guard hasSettled, !reduceMotion else { return nil }
        return .easeOut(duration: ProjectVisibilityMotion.seconds)
    }

    private var subagentMotion: Animation? {
        guard hasSettled,
              let seconds = ProjectVisibilityMotion.subagentRemoval(reduceMotion: reduceMotion)
                  .seconds
        else { return nil }
        return .easeOut(duration: seconds)
    }

    private func regroup(rescoped: Bool = false) {
        groups = SidebarRepoGroup.build(
            repos: app.repos,
            workspaces: app.workspaces,
            filter: filter,
            showingHidden: showsHiddenProjects
        )
        paneRows = SidebarPaneRow.rows(
            groups, crew: app.crew(of:), subagents: app.subagents(of:), pending: pending(in:),
            showsDraft: app.showsDraft(in:)
        )
        let ids = groups.flatMap { $0.workspaces.map(\.id) } + app.pendingWorkspaces.map(\.id)
        workspaceIdentities = Set(ids)
        if rescoped {
            arrival.adopt(ids)
        } else {
            arrival.absorb(ids)
        }
    }

    private func pending(in repoID: RepoID) -> [PendingWorkspace] {
        app.drawnPending(in: repoID)
    }

    private func reflow() {
        paneRows = SidebarPaneRow.rows(
            groups, crew: app.crew(of:), subagents: app.subagents(of:), pending: pending(in:),
            showsDraft: app.showsDraft(in:)
        )
    }

    private func move(from: IndexSet, to: Int) {
        switch SidebarReorder.destination(rows: paneRows.map(\.identity), from: from, to: to) {
        case .nothing:
            break

        case .project(let id, let offset):
            let visible = groups.map(\.id)
            Task { await app.reorderProjects(id: id, visible: visible, to: offset) }

        case .workspace(let projectID, let offsets, let offset, let landedOutside):
            guard let group = groups.first(where: { $0.id == projectID }) else { return }
            if landedOutside { note("Kept in \(group.repo.name)") }
            Task {
                await app.reorderWorkspaces(
                    in: group.repo, visible: group.workspaces, from: offsets, to: offset
                )
            }
        }
    }

    private func note(_ sentence: String) {
        reorderNote = ReorderNote(sentence: sentence)
    }

    private func commitSelection(_ target: SidebarSelection, replacing previous: SidebarSelection) {
        guard listSelection == target, app.selection == previous else { return }
        if let id = target.workspaceID, !app.workspaces.contains(where: { $0.id == id }) {
            listSelection = app.selection
            return
        }
        app.selection = target
    }

    private func archiveFromKeyboard(_ workspace: Workspace) {
        WorkspaceHoverCardPresenter.shared.pointerExited(.workspaceRow(workspace.id))
        let generation = archivePresentation.begin(workspaceID: workspace.id, source: .row)
        Task {
            defer { archivePresentation.finish(generation: generation) }
            await app.archive(workspace) { request in
                archivePresentation.present(request, generation: generation)
            }
        }
    }

    private func workspaceRow(_ workspace: Workspace, projectName: String) -> some View {
        let target = SidebarSelection.workspace(workspace.id)
        return SidebarWorkspaceRow(
            workspace: workspace,
            arrival: arrival,
            projectName: projectName,
            renaming: $renaming,
            archivePresentation: $archivePresentation
        )
        .tag(target)
    }

    private func navRow(_ target: SidebarSelection, title: String, icon: String) -> some View {
        SidebarNavRow(title: title, icon: icon)
            .tag(target)
    }

    private var askRow: some View {
        HStack(spacing: 0) {
            SidebarNavRow(title: AskConversation.title, icon: PaneGlyph.chat)
            Spacer(minLength: Metrics.spacingSmall)
            if let status = app.askStatus {
                WorkspaceStatusGlyph(status: status, isOnSelection: false)
            }
        }
        .tag(SidebarSelection.ask)
    }

    private func isSelected(_ target: SidebarSelection) -> Bool {
        listSelection == target
    }

    private static let crewStopMessage =
        "It is working now, and the turn it is in the middle of is lost. Everything it has "
        + "already written in the worktree stays exactly as it is, and its conversation stays "
        + "here to read. The agent that started it is told."

    struct PendingCrewStop: Equatable {
        var sessionID: SessionID
        var workspaceID: WorkspaceID
        var name: String
    }

    private func askToStop(_ member: CrewRow, in workspaceID: WorkspaceID) {
        let pending = PendingCrewStop(
            sessionID: member.id, workspaceID: workspaceID, name: member.name
        )

        switch member.state {
        case .running, .waiting: stoppingCrew = pending
        case .idle, .failed, .cancelled: Task { await stop(pending) }
        }
    }

    private func stop(_ pending: PendingCrewStop) async {
        guard let model = app.existingModel(for: pending.workspaceID),
              let member = model.sessions.first(where: { $0.id == pending.sessionID })
        else { return }

        await model.closeCrewMember(member)
    }

    private func presentCreate(in repo: Repo?) {
        renaming = nil
        app.openDraft(in: repo)
    }

    private func startProject() {
        NotificationCenter.default.post(name: .udNewProject, object: nil)
    }
}

struct SidebarNavRow: View {
    var title: String
    var icon: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
        }
    }
}

extension View {
    func selectedRowInk(isEmphasized: Bool) -> some View {
        environment(\.backgroundProminence, isEmphasized ? .increased : .standard)
            .foregroundStyle(isEmphasized ? Palette.selectedEmphasizedText : Palette.textPrimary)
    }
}
