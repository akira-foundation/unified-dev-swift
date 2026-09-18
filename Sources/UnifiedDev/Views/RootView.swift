import AppKit
import SwiftUI
import Core

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    @Bindable private var projectSetup = ProjectSetup.shared
    @Bindable private var closeSession = CloseSessionAlert.shared
    @Bindable private var setupRun = SetupRunAlert.shared
    @Bindable private var feedback = FeedbackPresenter.shared

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var centreWidth: CGFloat = 0

    var body: some View {
        @Bindable var app = app

        return windowWiring(
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(
                        min: UnifiedDevApp.sidebarMinimumWidth,
                        ideal: Metrics.sidebarWidth,
                        max: sidebarCeiling ?? UnifiedDevApp.sidebarMinimumWidth
                    )
            } content: {
                DetailColumn()
                    .navigationSplitViewColumnWidth(
                        min: Metrics.centreColumnMinimum,
                        ideal: Metrics.centreColumnIdeal,
                        max: .infinity
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { centreWidth = $0 }
                    .noticeStage()
                    .toolbar {
                        WindowToolbar(
                            app: app,
                            centreWidth: centreWidth,
                            startFreshAskConversation: { Task { await app.ask.newConversation() } }
                        )
                    }
            } detail: {
                InspectorColumn()
                    .navigationSplitViewColumnWidth(
                        min: Metrics.inspectorMinimum,
                        ideal: Metrics.inspectorWidth,
                        max: Metrics.inspectorMaximum
                    )
            }
            .collapsesLastColumn(when: app.selectedModel == nil)
            .navigationTitle(WindowTitleMark.decorate(app.menuWorkspace?.name ?? WindowTitleMark.defaultTitle))
            .toolbar(removing: WindowToolbar.showsTabs(in: app) ? .title : nil)

            .focusedSceneValue(\.isMainWindowFocused, true)

            .onChange(of: sidebarCeiling == nil, initial: true) { _, folds in
                if folds { columnVisibility = .detailOnly }
            }

            .task { await app.bootstrap() }
            .task { InstallPingService.shared.start(app: app) }
            .task { FeedbackPresenter.shared.presentIfRequested() }
            .task { presentSearchPanelIfRequested() }
            .sheet(item: $feedback.sheet) { sheet in
                switch sheet {
                case .report: FeedbackSheet()
                case .prompt: PromptSubmissionSheet()
                case .reportSent:
                    FeedbackSentCard(
                        title: Feedback.Copy.reportSent,
                        detail: Feedback.Copy.reportSentDetail,
                        onDismiss: feedback.close
                    )
                case .promptSent:
                    FeedbackSentCard(
                        title: Feedback.Copy.promptSent,
                        detail: Feedback.Copy.promptSentDetail,
                        onDismiss: feedback.close
                    )
                }
            }
            .sheet(item: $projectSetup.request.on(.main)) { request in
                ProjectSetupSheet(request: request) { path in
                    Task { await app.finishProjectSetup(path) }
                }
            }
            .confirmationDialog(
                "Archive this workspace?",
                isPresented: $app.pendingArchive.isPresent(),
                titleVisibility: .visible,
                presenting: app.pendingArchive
            ) { request in
                Button(
                    request.confirmLabel, role: request.isDestructive ? .destructive : nil
                ) { confirmArchive(request) }
                Button(request.cancelLabel, role: .cancel, action: app.cancelPendingArchive)
            } message: { request in
                Text(request.message)
            }
            .confirmationDialog(
                closeSession.request?.title ?? "",
                isPresented: $closeSession.request.isPresent(),
                titleVisibility: .visible,
                presenting: closeSession.request
            ) { request in
                Button(request.cost.confirmTitle, role: .destructive) { closeSession.confirm() }
                Button(request.cost.cancelTitle, role: .cancel) { closeSession.cancel() }
            } message: { request in
                Text(request.message)
            }
            .confirmation($setupRun.request) { request in
                Confirmation(
                    title: request.question.title,
                    message: request.question.message,
                    confirmLabel: request.question.confirmLabel,
                    cancelLabel: request.question.cancelLabel
                )
            } onConfirm: { request in
                request.model.runSetupAgain()
            }
            .alert(
                app.alert?.title ?? "",
                isPresented: $app.alert.isPresent(),
                presenting: app.alert
            ) { _ in
            } message: { alert in
                Text(alert.message)
            }
            .onReceive(OpenWorkspaceNotification.publisher()) { id in
                Task { await app.open(workspaceID: id) }
            }
        )
    }

    private func presentSearchPanelIfRequested() {
        #if DEBUG
        SearchPanelModel.shared.presentIfRequested(app: app)
        #endif
    }

    private func windowWiring(_ content: some View) -> some View {
        content
        .searchPanel(app: app)
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevFocusSearch)) { _ in
            SearchPanelModel.shared.open(scope: .transcripts, app: app)
        }
        .onChange(of: app.homeFilter.query) { old, new in
            let was = !WorkspaceSearch.needle(old).isEmpty
            let now = !WorkspaceSearch.needle(new).isEmpty
            guard was != now else { return }
            app.homeFilter.scope = HomeScope.settle(app.homeFilter.scope, searching: now)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevToggleSidebar)) { _ in
            toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevOfferProjectSetup)) { note in
            guard let path = note.object as? String else { return }
            Task { await app.addRepository(at: path) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevOpenRepoSettings)) { note in
            let named = note.object as? String
            let repo = app.repos.first { $0.name == named } ?? app.repos.first
            guard let repo else { return }
            openWindow(id: RepoSettingsWindow.id, value: repo.id)
        }
        .acceptsCaptureRunningState(app)
        .acceptsCaptureNotice(app)
        .onReceive(NotificationCenter.default.publisher(for: .udNewProject)) { _ in
            openWindow(id: StartProjectWindow.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .udNewAskConversation)) { _ in
            app.selection = .ask
            Task { await app.ask.newConversation() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .udNewWorkspace)) { note in
            app.openDraft(
                in: note.object as? Repo,
                asksForStartingPoint: note.userInfo?[Notification.unifieddevPullRequestKey] as? Bool == true
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .unifieddevStartTerminalWorkspace)) { note in
            let named = note.object as? String
            let repo = app.repos.first { $0.name == named } ?? app.repos.first
            guard let repo else { return }
            Task { await app.createWorkspace(in: repo, prompt: "", opensWith: .terminal) }
        }
    }

    private func toggleSidebar() {
        withAnimation(reduceMotion ? nil : Motion.pane) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }

    private var isInspectorPresented: Bool { app.isInspectorPresented }

    private var inspectorPresented: Binding<Bool> {
        Binding(get: { app.isInspectorPresented }, set: { _ in })
    }

    private var sidebarCeiling: CGFloat? {
        UnifiedDevApp.widths.sidebarMaximum(
            sharing: NSScreen.main?.visibleFrame.width ?? .greatestFiniteMagnitude,
            withInspector: isInspectorPresented
        )
    }

    private func confirmArchive(_ request: ArchiveRequest) {
        Task { await app.confirmArchive(request) }
    }
}

extension Notification.Name {
    static let unifieddevToggleSidebar = Notification.Name("unifieddev.toggleSidebar")
    static let unifieddevFocusSearch = Notification.Name("unifieddev.focusSearch")
    static let udNewWorkspace = Notification.Name("unifieddev.newWorkspace")
    static let udNewAskConversation = Notification.Name("unifieddev.newAskConversation")
    static let udNewProject = Notification.Name("unifieddev.newProject")
    static let unifieddevStartTerminalWorkspace = Notification.Name("unifieddev.startTerminalWorkspace")
    static let unifieddevRenameWorkspace = Notification.Name("unifieddev.renameWorkspace")
    static let unifieddevRenameTab = Notification.Name("unifieddev.renameTab")
}

extension Notification {
    static let unifieddevPullRequestKey = "unifieddev.newWorkspace.pullRequest"
    static let unifieddevWorkspaceIDKey = "unifieddev.workspaceID"
}

private struct InspectorColumn: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let model = app.selectedModel {
            InspectorView(model: model)
        } else {
            Color.clear
        }
    }
}
