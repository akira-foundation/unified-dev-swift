import SwiftUI
import Core

struct SessionTabsView: View {
    @Bindable var model: WorkspaceModel

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: StripDrag?
    @State private var centres = GeometryBox([PaneContent: Double]())
    @Namespace private var selection

    private struct StripDrag: Equatable {
        var tab: PaneContent
        var run: [PaneContent]
        var centres: [PaneContent: Double]
        var order: [PaneContent]
    }

    private static let stripSpace = "unifieddev.tabStrip"

    private var tabs: CenterTabStore { .shared }

    private var store: WorkspaceTabsStore { .shared }

    private var renameField: TabRenameField { .shared }

    private var renamingID: String? { renameField.id(in: model.workspace.id) }

    private func startRename(_ id: String) {
        renameField.begin(id, in: model.workspace.id)
    }

    private func endRename() {
        renameField.end(in: model.workspace.id)
    }

    private var stored: [PaneContent] {
        store.entries(in: model)
    }

    private var entries: [PaneContent] {
        guard let drag, Set(drag.order) == Set(stored) else { return stored }
        return drag.order
    }

    var body: some View {
        let entries = self.entries
        let selected = store.selectedTab(in: model, entries: entries)
        let selectedID = selected.flatMap { entries.contains($0) ? AnyHashable($0.id) : nil }
        return TabStrip(pane: Self.pane, selection: selectedID, tabCount: entries.count) {
        } tabs: {
            HStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element) { _, entry in
                    switch entry {
                    case .chat(let id):
                        if let session = session(id) {
                            sessionTab(session, selected: selected, entries: entries)
                                .id(id)
                        }
                    case .tool(let id):
                        if let tab = tool(id) {
                            toolTab(tab, selected: selected, entries: entries)
                                .id(id)
                        }
                    }
                }
            }
            .coordinateSpace(.named(Self.stripSpace))
            .onDropSessionUpdated { session in
                switch session.phase {
                case .entering, .active: follow(session.location.x)
                default: return
                }
            }
            .dropDestination(for: String.self) { items, session in
                commit(items.first, at: session.location.x)
            }
            .animation(reduceMotion ? nil : Motion.pane, value: drag?.order)
        } append: {
        } trailing: {}
    }

    private static let pane = TabPane.content

    private func session(_ id: SessionID) -> Session? {
        model.sessions.first { $0.id == id }
    }

    private func tool(_ id: String) -> CenterTab? {
        tabs.tabs(for: model.workspace.id).first { $0.id == id }
    }

    private func isSeparated(
        at index: Int, in entries: [PaneContent], selected: PaneContent?
    ) -> Bool {
        guard index > 0 else { return false }
        return entries[index - 1] != selected && entries[index] != selected
    }

    private func sessionTab(
        _ session: Session, selected: PaneContent?, entries: [PaneContent]
    ) -> some View {
        SessionTabView(
            session: session,
            agentGlyph: sessionGlyph(for: session),
            isActive: selected == .chat(session.id),
            isRunning: model.isRunning(session),
            isRenaming: renamingID == session.id.rawValue,
            canClose: true,
            onSelect: { select(session) },
            onStartRename: { startRename(session.id.rawValue) },
            onCommitRename: { commitRename(session, to: $0) },
            onCancelRename: { endRename() },
            onClose: { close(session) },
            onSplitRight: splitAction(.chat(session.id), axis: .horizontal, selected: selected),
            onSplitDown: splitAction(.chat(session.id), axis: .vertical, selected: selected),
            onMoveLeft: moveAction(.chat(session.id), by: -1, in: entries),
            onMoveRight: moveAction(.chat(session.id), by: 1, in: entries),
            namespace: selection
        )
        .draggable(session.id.rawValue)
        .modifier(StripDragTracking(
            content: .chat(session.id),
            space: Self.stripSpace,
            onMeasure: { centres.value[.chat(session.id)] = $0 },
            onBegin: { begin(.chat(session.id)) },
            onEnd: { finish(taken: $0) }
        ))
    }

    private func sessionGlyph(for session: Session) -> String? {
        if let turn = TerminalSessionStore.shared.agentTurns[session.id], turn.isAwaitingPermission {
            return "questionmark.circle"
        }
        if CenterTabStore.shared.terminal(for: session.id, in: model.workspace.id) != nil {
            return PaneGlyph.agentMark(for: session.agentKind)
        }
        return PaneGlyph.agentMark(for: session.agentKind, among: model.sessions.map(\.agentKind))
    }

    private func toolTab(
        _ tab: CenterTab, selected: PaneContent?, entries: [PaneContent]
    ) -> some View {
        TabItemView(
            title: tabs.displayTitle(of: tab, in: model),
            icon: icon(for: tab),
            isActive: selected == .tool(tab.id),
            isRunning: launcher.isRunning(tab),
            surface: Self.pane.surface,
            isRenaming: renamingID == tab.id,
            editableTitle: tabs.displayTitle(of: tab, in: model),
            canClose: true,
            canRename: TabRenaming.canRename(.tool(tab.id), tabKind: tab.kind),
            closeTitle: closeTitle(for: tab),
            onSelect: { store.select(.tool(tab.id), in: model) },
            onStartRename: { startRename(tab.id) },
            onCommitRename: {
                endRename()
                tabs.rename(tab, to: $0)
            },
            onCancelRename: { endRename() },
            onClose: { Task { await tabs.close(tab, in: model) } },
            onSplitRight: splitAction(.tool(tab.id), axis: .horizontal, selected: selected),
            onSplitDown: splitAction(.tool(tab.id), axis: .vertical, selected: selected),
            onMoveLeft: moveAction(.tool(tab.id), by: -1, in: entries),
            onMoveRight: moveAction(.tool(tab.id), by: 1, in: entries),
            namespace: selection
        )
        .draggable(tab.id)
        .modifier(StripDragTracking(
            content: .tool(tab.id),
            space: Self.stripSpace,
            onMeasure: { centres.value[.tool(tab.id)] = $0 },
            onBegin: { begin(.tool(tab.id)) },
            onEnd: { finish(taken: $0) }
        ))
    }

    private func icon(for tab: CenterTab) -> TabItemIcon {
        if tab.kind == .terminal,
           let agent = TerminalSessionStore.shared.detectedAgent(inTab: tab.id) {
            return .symbol(PaneGlyph.agentMark(for: agent))
        }
        if tab.kind == .terminal, let script = runScript(of: tab) {
            return .symbol(RunScriptGlyph.symbol(for: script.icon))
        }
        guard tab.kind == .browser else { return .symbol(tab.icon) }
        return .page(BrowserFaviconStore.shared.icon(for: tab.url))
    }

    private func runScript(of tab: CenterTab) -> RunScript? {
        guard let id = tab.runScriptID else { return nil }
        return model.settings.runScripts.first { $0.id == id }
    }

    private var launcher: RunScriptLauncher { .shared }

    private func closeTitle(for tab: CenterTab) -> String {
        switch tab.kind {
        case .terminal: "Close terminal"
        case .browser: "Close browser"
        case .review: "Close the review"
        case .notes: "Close the notes"
        }
    }

    private func splitAction(
        _ content: PaneContent, axis: SplitAxis, selected: PaneContent?
    ) -> (@MainActor () -> Void)? {
        guard canSplit(content, selected: selected) else { return nil }
        return { split(content, axis: axis) }
    }

    private func moveAction(
        _ content: PaneContent, by step: Int, in entries: [PaneContent]
    ) -> (@MainActor () -> Void)? {
        guard let order = TabDragOrder.moved(entries, moving: content, by: step) else { return nil }
        return { settle(order) }
    }

    private func canSplit(_ content: PaneContent, selected: PaneContent?) -> Bool {
        guard let selected else { return false }
        guard content != selected else { return duplicable(content) }
        return store.canAbsorb(content)
    }

    private func duplicable(_ content: PaneContent) -> Bool {
        PaneDuplicate.canOpen(content, in: model)
    }

    private func split(_ content: PaneContent, axis: SplitAxis) {
        guard let tab = store.selectedTab(in: model) else { return }
        let pane = store.focusedPane(of: tab)

        guard content != tab else {
            return PaneDuplicate.open(content, in: model) {
                store.split(tab: tab, pane: pane, axis: axis, showing: $0)
            }
        }
        store.split(tab: tab, pane: pane, axis: axis, showing: content)
    }

    private func begin(_ tab: PaneContent) {
        guard drag?.tab != tab else { return }
        let run = stored
        guard run.count > 1, run.contains(tab) else { return }
        drag = StripDrag(tab: tab, run: run, centres: centres.value, order: run)
    }

    private func follow(_ pointer: Double) {
        guard var current = drag else { return }
        let order = TabDragOrder.live(
            current.run, moving: current.tab, centres: current.centres, to: pointer
        )
        guard order != current.order else { return }
        current.order = order
        drag = current
    }

    private func commit(_ droppedID: String?, at pointer: Double) {
        guard let tab = drag?.tab ?? droppedID.flatMap(content(named:)) else { return }
        let run = drag?.run ?? stored
        guard run.count > 1, run.contains(tab) else { return drag = nil }

        settle(drag?.order ?? TabDragOrder.live(
            run, moving: tab, centres: drag?.centres ?? centres.value, to: pointer
        ))
    }

    private func finish(taken: Bool) {
        guard let current = drag else { return }
        guard taken else { return drag = nil }
        settle(current.order)
    }

    private func settle(_ order: [PaneContent]) {
        drag = nil
        store.reorder(order, in: model)
        reorderSessions(within: order)
        reorderTools(within: order)
    }

    private func content(named id: String) -> PaneContent? {
        if model.sessions.contains(where: { $0.id.rawValue == id }) { return .chat(SessionID(id)) }
        if tabs.tabs(for: model.workspace.id).contains(where: { $0.id == id }) { return .tool(id) }
        return nil
    }

    private func reorderSessions(within strip: [PaneContent]) {
        let drawn = strip.compactMap { entry -> SessionID? in
            guard case .chat(let id) = entry else { return nil }
            return id
        }
        guard let order = TabReorder.apply(drawn, to: model.sessions.map(\.id)) else { return }
        model.reorderSessions(to: order)
    }

    private func reorderTools(within strip: [PaneContent]) {
        let drawn = strip.compactMap { entry -> String? in
            guard case .tool(let id) = entry else { return nil }
            return id
        }
        let stored = tabs.tabs(for: model.workspace.id).map(\.id)
        guard let order = TabReorder.apply(drawn, to: stored) else { return }
        tabs.reorder(order, in: model.workspace.id)
    }

    private func select(_ session: Session) {
        store.select(.chat(session.id), in: model)
    }

    private func close(_ session: Session) {
        CloseSessionAlert.shared.close(session, in: model)
    }

    private func commitRename(_ session: Session, to newTitle: String) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        endRename()
        guard !title.isEmpty, title != session.title, let store = app.store else { return }

        let updated = session.with { $0.title = title }
        if let index = model.sessions.firstIndex(where: { $0.id == session.id }) {
            model.sessions[index] = updated
        }
        Task {
            try? await store.updateSessionPreferences(id: session.id, title: title)
            await model.reloadSessions()
        }
    }
}
