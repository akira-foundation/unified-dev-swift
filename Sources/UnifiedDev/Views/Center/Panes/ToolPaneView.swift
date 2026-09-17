import SwiftUI
import Core

struct ToolPaneView: View {
    @Bindable var model: WorkspaceModel
    var tab: CenterTab
    var siblings: [PaneContent] = []
    var splitColumn: @MainActor (SplitAxis, PaneKind) -> Void
    var paneMenu: (@MainActor () -> NSMenu)?

    @State private var readyTabID: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var app

    var body: some View {
        switch tab.kind {
        case .terminal:
            VStack(spacing: 0) {
                WorktreeSetupStrip(readiness: readiness)

                Group {
                    if readyTabID == tab.id {
                        TerminalSplitView(
                            ownerID: tab.id,
                            workspace: model.workspace,
                            repo: model.repo,
                            port: model.port,
                            directory: tab.directory,
                            runScript: runScript,
                            onCloseTab: {
                                Task {
                                    if let sessionID = tab.agentSessionID,
                                       let session = model.sessions.first(where: { $0.id == sessionID }) {
                                        await model.closeSession(session)
                                    } else {
                                        await CenterTabStore.shared.close(tab)
                                    }
                                }
                            },
                            splitColumn: splitColumn,
                            terminalLabel: tab.title,
                            onAddToChat: terminalHandoff
                        )
                        .id(tab.id)
                    } else {
                        LoadingView("Opening a terminal")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(reduceMotion ? nil : Motion.pane, value: readiness)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: tab.id) { await prepareTerminal() }

        case .browser:
            BrowserTabView(model: model, tab: tab, paneMenu: paneMenu, siblings: siblings)
                .id(tab.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .review:
            ReviewPaneView(model: model, tab: tab, siblings: siblings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .notes:
            NotesPaneView(model: model)
                .id(model.workspace.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var runScript: RunScript? {
        guard let id = tab.runScriptID else { return nil }
        return model.settings.runScripts.first { $0.id == id }
    }

    private var readiness: WorktreeReadiness {
        WorktreeReadiness.of(
            isRunningSetup: model.isRunningSetup,
            setupState: model.workspace.setupState
        )
    }

    private var terminalHandoff: (@MainActor (TerminalExcerpt) -> Void)? {
        guard let sessionID = model.activeSession?.id else { return nil }
        let destination = model
        return { excerpt in
            Task { @MainActor in
                if let failure = await TerminalExcerptHandoff.attach(excerpt, to: destination, sessionID: sessionID) {
                    app.notice = Notice(message: failure)
                }
            }
        }
    }

    private func prepareTerminal() async {
        TerminalSessionStore.shared.useStore(model.store)
        await model.ensurePort()
        readyTabID = tab.id
    }
}
