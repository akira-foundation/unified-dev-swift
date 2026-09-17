import SwiftUI
import Core

struct CenterPaneView: View {
    @Bindable var model: WorkspaceModel
    var tab: PaneContent?
    var pane: String
    var isSplit: Bool

    @State private var size = GeometryBox(CGSize.zero)
    @State private var isTargeted = false
    @State private var landing: PaneRegion?

    private var tabs: WorkspaceTabsStore { .shared }

    private var showing: PaneContent? {
        tab.map { tabs.content(of: pane, in: $0) }
    }

    private var paneContents: [PaneContent] {
        guard let tab else { return [] }
        return tabs.layout(of: tab).panes.map { tabs.content(of: $0, in: tab) }
    }

    private var waiting: PaneWait? {
        switch showing {
        case .chat(let sessionID):
            if CenterTabStore.shared.terminal(for: sessionID, in: model.workspace.id) != nil { return nil }
            if model.existingTranscript(for: sessionID) != nil { return nil }
            if model.sessions.contains(where: { $0.id == sessionID }) {
                return .conversation(sessionID)
            }
            return model.hasReadSessions ? nil : .sessions(model.workspace.id)
        case .tool:
            return nil
        case nil:
            guard !model.isRunningSetup, !model.hasReadSessions else { return nil }
            return .sessions(model.workspace.id)
        }
    }

    var body: some View {
        content
            .overlay {
                SlowLoadingView(subject: waiting, label: waiting?.label)
                    .allowsHitTesting(false)
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size.value = $0 }
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard let tab else { return }
                    tabs.focus(pane, in: tab, of: model)
                }
            )
            .dropDestination(for: String.self) { items, location in
                accept(items.first, at: location)
            } isTargeted: {
                isTargeted = $0
                if !$0 { landing = nil }
            }
            .onDropSessionUpdated { session in
                switch session.phase {
                case .entering, .active: landing = PaneRegion.at(session.location, in: size.value)
                default: landing = nil
                }
            }
            .overlay { dropHighlight }
            .contextMenu { menu }
            .task(id: showing) { prepare() }
    }

    private func prepare() {
        guard case .chat(let sessionID)? = showing else { return }
        model.prepareTranscript(for: sessionID)
    }

    @ViewBuilder
    private var content: some View {
        let _ = SwitchTrace.mark("pane.body", workspace: model.workspace.id)
        let _ = SwitchTrace.markOnScreen("pane.body", workspace: model.workspace.id)

        switch showing {
        case .chat(let sessionID):
            switch chatContent(for: sessionID) {
            case let .cliSetup(terminal):
                cliSetup(terminal, sessionID: sessionID)
            case let .terminal(terminal):
                ToolPaneView(
                    model: model, tab: terminal, siblings: paneContents,
                    splitColumn: { split($0, opening: $1) }, paneMenu: hostedMenu
                )
            case let .chat(transcript):
                ChatPaneView(transcript: transcript, model: model, pane: pane)
            case .waiting:
                waitingSurface
            case .empty:
                emptyState
            }

        case .tool(let tabID):
            if let tab = CenterTabStore.shared.tabs(for: model.workspace.id)
                .first(where: { $0.id == tabID }) {
                ToolPaneView(
                    model: model, tab: tab,
                    siblings: paneContents,
                    splitColumn: { split($0, opening: $1) },
                    paneMenu: hostedMenu
                )
            } else {
                emptyState
            }

        case nil:
            if model.isRunningSetup {
                setupState
            } else if !model.hasReadSessions {
                waitingSurface
            } else if model.sessions.isEmpty {
                noConversationState
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var dropHighlight: some View {
        if isTargeted, let landing {
            GeometryReader { proxy in
                let frame = landing.frame(in: CGRect(origin: .zero, size: proxy.size))
                Rectangle()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
            }
            .allowsHitTesting(false)
        }
    }

    private var menu: CenterPaneMenu {
        CenterPaneMenu(
            isSplit: isSplit,
            split: { axis, kind in split(axis, opening: kind) },
            close: {
                guard let tab else { return }
                tabs.close(pane: pane, in: tab, of: model.workspace.id)
            }
        )
    }

    private func hostedMenu() -> NSMenu {
        NSHostingMenu(rootView: menu)
    }

    private func split(_ axis: SplitAxis, opening kind: PaneKind) {
        guard let tab else { return }
        let pane = pane

        NewPane.open(kind, in: model) { content in
            WorkspaceTabsStore.shared.split(tab: tab, pane: pane, axis: axis, showing: content)
        }
    }

    private func accept(_ droppedID: String?, at location: CGPoint) -> Bool {
        guard let tab, let droppedID, let dropped = droppedTab(named: droppedID) else { return false }
        guard tabs.canAbsorb(dropped) else { return false }

        guard let placement = PaneRegion.at(location, in: size.value).placement else {
            tabs.replace(pane: pane, of: tab, with: dropped, in: model)
            return true
        }
        tabs.split(
            tab: tab, pane: pane,
            axis: placement.axis, showing: dropped, before: placement.before
        )
        return true
    }

    private func droppedTab(named id: String) -> PaneContent? {
        if model.sessions.contains(where: { $0.id.rawValue == id }) { return .chat(SessionID(id)) }
        if CenterTabStore.shared.tabs(for: model.workspace.id).contains(where: { $0.id == id }) {
            return .tool(id)
        }
        return nil
    }

    private enum ChatContent {
        case cliSetup(CenterTab)
        case terminal(CenterTab)
        case chat(TranscriptModel)
        case waiting
        case empty
    }

    private func chatContent(for sessionID: SessionID) -> ChatContent {
        if let terminal = CenterTabStore.shared.terminal(for: sessionID, in: model.workspace.id) {
            return model.pendingCLILaunches.contains(sessionID)
                ? .cliSetup(terminal)
                : .terminal(terminal)
        }
        if let transcript = model.existingTranscript(for: sessionID) { return .chat(transcript) }
        if model.sessions.contains(where: { $0.id == sessionID }) { return .waiting }
        if !model.hasReadSessions { return .waiting }
        return .empty
    }

    private var waitingSurface: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cliSetup(_ terminal: CenterTab, sessionID: SessionID) -> some View {
        TerminalView(
            tab: TerminalTab(id: TerminalTabID(terminal.id), workspaceID: model.workspace.id, title: terminal.title),
            workspace: model.workspace, repo: model.repo, port: model.port,
            output: (model.sessions.first { $0.id == sessionID }?.agentKind ?? .claudeCode)
                .interactiveSetupOutput(prompt: model.pendingCLIPrompts[sessionID], log: model.setupOutput)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var setupState: some View {
        EmptyStateView(
            glyph: "gearshape.2",
            title: "Setting up the workspace",
            message: "The setup script is still running. The first session opens as soon as it finishes."
        )
    }

    private var emptyState: some View {
        EmptyStateView(
            glyph: "bubble.left.and.bubble.right",
            title: "No session in this pane",
            message: "Sessions share the worktree but not the conversation, so a new one starts with a clean context.",
            actionTitle: "Start a session",
            action: { NewPane.open(.chat, in: model) { tabs.reveal($0, in: model) } }
        )
    }

    private var noConversationState: some View {
        VStack(spacing: Metrics.spacingWide) {
            EmptyStateView(
                glyph: "apple.terminal",
                title: "Nothing open in this pane",
                message: "Open one of these in the worktree."
            )

            HStack(spacing: Metrics.spacing) {
                ForEach(PaneKind.allCases) { kind in
                    Button {
                        NewPane.open(kind, in: model) { tabs.reveal($0, in: model) }
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.controlAccent)
                }
            }
        }
    }

    private func openTerminal() {
        NewPane.open(.terminal, in: model) { tabs.reveal($0, in: model) }
    }
}
