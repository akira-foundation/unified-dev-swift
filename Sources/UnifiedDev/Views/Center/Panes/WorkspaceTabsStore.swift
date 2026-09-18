import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class WorkspaceTabsStore {
    static let shared = WorkspaceTabsStore()

    private struct Arrangement {
        var root: PaneContent
        var layout: SplitLayout
        var contents: [String: PaneContent]

        init(root: PaneContent, layout: SplitLayout, contents: [String: PaneContent]) {
            self.root = root
            self.layout = layout
            self.contents = contents
        }

        init?(root: PaneContent, stored: StoredPaneArrangement) {
            guard let layout = SplitLayout(encoded: stored.layout) else { return nil }
            self.init(root: root, layout: layout, contents: stored.contents)
        }

        var stored: StoredPaneArrangement? {
            guard let encoded = layout.encoded else { return nil }
            let panes = Set(layout.panes)
            return StoredPaneArrangement(
                layout: encoded, contents: contents.filter { panes.contains($0.key) }
            )
        }

        func canHold(_ content: PaneContent) -> Bool {
            guard case .tool = content else { return true }
            return !layout.panes.contains { contents[$0] == content }
        }
    }

    private var arrangements: [String: Arrangement] = [:]

    private var selected: [WorkspaceID: PaneContent] = [:]

    private var stripOrders: [WorkspaceID: [PaneContent]] = [:]

    private init() {
        let defaults = UserDefaults.standard
        var snapshot = DefaultsSnapshot.own(defaults, name: Bundle.main.bundleIdentifier)

        for tab in TabMigration.migrateAll(in: defaults, keys: snapshot.keys) {
            guard let data = defaults.data(forKey: tab.key) else { continue }
            snapshot[tab.key] = data
        }

        for (key, value) in snapshot
        where key.hasPrefix(TabDefaults.tabPrefix) {
            let rootID = String(key.dropFirst(TabDefaults.tabPrefix.count))
            guard let data = value as? Data,
                  let stored = StoredPaneArrangement(decoding: data),
                  let root = stored.contents.values.first(where: { $0.id == rootID }),
                  let arrangement = Arrangement(root: root, stored: stored) else {
                defaults.removeObject(forKey: key)
                continue
            }
            arrangements[rootID] = arrangement
        }

        for (key, value) in snapshot
        where key.hasPrefix(TabDefaults.stripPrefix) {
            let workspaceID = WorkspaceID(String(key.dropFirst(TabDefaults.stripPrefix.count)))
            guard let data = value as? Data,
                  let order = try? JSONDecoder().decode([PaneContent].self, from: data) else {
                defaults.removeObject(forKey: key)
                continue
            }
            stripOrders[workspaceID] = order
        }
    }

    func entries(in model: WorkspaceModel) -> [PaneContent] {
        let sessions = TabSet.tabbable(model.sessions)
        let tools = CenterTabStore.shared.stripToolIDs(for: model.workspace.id)
        return StripOrder.entries(
            sessions: sessions,
            tools: tools,
            claimed: claimed(sessions: sessions, tools: tools),
            stored: stripOrders[model.workspace.id] ?? []
        )
    }

    func reorder(_ drawn: [PaneContent], in model: WorkspaceModel) {
        let workspaceID = model.workspace.id
        guard let order = StripOrder.rewritten(
            drawn,
            sessions: TabSet.tabbable(model.sessions),
            tools: CenterTabStore.shared.stripToolIDs(for: workspaceID),
            stored: stripOrders[workspaceID] ?? []
        ) else { return }

        stripOrders[workspaceID] = order
        persistStrip(workspaceID)
    }

    func updateOrder(
        sessions: [SessionID]? = nil, tools: [String]? = nil, workspaceID: WorkspaceID
    ) {
        let previous = stripOrders[workspaceID] ?? []
        let order = StripOrder.updated(sessions: sessions, tools: tools, stored: previous)
        guard order != previous else { return }
        stripOrders[workspaceID] = order
        persistStrip(workspaceID)
    }

    func prepareToClose(_ content: PaneContent, in model: WorkspaceModel) {
        let entries = entries(in: model)
        guard let current = selectedTab(in: model, entries: entries), current == content else { return }
        if selected[model.workspace.id] != current { selected[model.workspace.id] = current }
        guard layout(of: current).panes.allSatisfy({ self.content(of: $0, in: current) == content }) else { return }
        if let next = TabClosure.selectionAfterClosing(content, selected: current, tabs: entries) {
            select(next, in: model)
        }
    }

    func selectedTab(in model: WorkspaceModel) -> PaneContent? {
        selectedTab(in: model, entries: entries(in: model))
    }

    func selectedTab(in model: WorkspaceModel, entries: [PaneContent]) -> PaneContent? {
        if let chosen = selected[model.workspace.id], entries.contains(chosen) { return chosen }

        if let active = model.activeSession.map({ PaneContent.chat($0.id) }) {
            if entries.contains(active) { return active }
            if let owner = entries.first(where: { claimedContents(of: $0).contains(active) }) {
                return owner
            }
        }
        return entries.first
    }

    private func persistStrip(_ workspaceID: WorkspaceID) {
        let defaults = UserDefaults.standard
        let key = TabDefaults.stripKey(workspaceID)
        guard let order = stripOrders[workspaceID], !order.isEmpty,
              let data = try? JSONEncoder().encode(order) else {
            return defaults.removeObject(forKey: key)
        }
        defaults.set(data, forKey: key)
    }

    func layout(of tab: PaneContent) -> SplitLayout {
        arrangements[tab.id]?.layout ?? SplitLayout(pane: tab.id)
    }

    func focusedPane(of tab: PaneContent) -> String {
        layout(of: tab).focus
    }

    func content(of pane: String, in tab: PaneContent) -> PaneContent {
        arrangements[tab.id]?.contents[pane] ?? tab
    }

    func canAbsorb(_ entry: PaneContent) -> Bool {
        arrangements[entry.id] == nil
    }

    private func claimedContents(of tab: PaneContent) -> Set<PaneContent> {
        guard let arrangement = arrangements[tab.id] else { return [] }
        return Set(arrangement.layout.panes.compactMap { arrangement.contents[$0] })
            .subtracting([tab])
    }

    private func claimed(sessions: [SessionID], tools: [String]) -> Set<PaneContent> {
        var claimed: Set<PaneContent> = []
        for tab in sessions.map(PaneContent.chat) + tools.map(PaneContent.tool) {
            claimed.formUnion(claimedContents(of: tab))
        }
        return claimed
    }

    func select(_ tab: PaneContent, in model: WorkspaceModel) {
        if selected[model.workspace.id] != tab { selected[model.workspace.id] = tab }
        adoptActiveSession(of: tab, in: model)
    }

    func selectNextTab(offset: Int, in model: WorkspaceModel) {
        let tabs = entries(in: model)
        guard let next = TabCycle.next(from: selectedTab(in: model), in: tabs, offset: offset) else {
            return
        }
        select(next, in: model)
    }

    func reveal(_ content: PaneContent, in model: WorkspaceModel, focusing: Bool = false) {
        if let current = selectedTab(in: model),
           let showing = layout(of: current).panes
               .first(where: { self.content(of: $0, in: current) == content }) {
            if focusing { focus(showing, in: current, of: model) }
            return
        }

        let entries = entries(in: model)
        if entries.contains(content) { return select(content, in: model) }

        guard let owner = entries.first(where: { claimedContents(of: $0).contains(content) }),
              let pane = layout(of: owner).panes
                  .first(where: { self.content(of: $0, in: owner) == content })
        else { return }

        selected[model.workspace.id] = owner
        focus(pane, in: owner, of: model)
    }

    func focus(_ pane: String, in tab: PaneContent, of model: WorkspaceModel) {
        if var arrangement = arrangements[tab.id], arrangement.layout.focus != pane,
           arrangement.layout.setFocus(pane) {
            arrangements[tab.id] = arrangement
            persist(tab.id)
        }
        adoptActiveSession(of: tab, in: model)
    }

    private func adoptActiveSession(of tab: PaneContent, in model: WorkspaceModel) {
        guard case .chat(let sessionID) = content(of: focusedPane(of: tab), in: tab),
              model.activeSessionID != sessionID else { return }
        model.activeSessionID = sessionID
    }

    @discardableResult
    func split(
        tab: PaneContent,
        pane: String? = nil,
        axis: SplitAxis,
        showing content: PaneContent? = nil,
        before: Bool = false
    ) -> String? {
        var arrangement = arrangements[tab.id]
            ?? Arrangement(root: tab, layout: SplitLayout(pane: tab.id), contents: [tab.id: tab])
        let target = pane ?? arrangement.layout.focus
        let placed = content ?? arrangement.contents[target] ?? tab

        guard arrangement.canHold(placed), placed == tab || canAbsorb(placed) else { return nil }

        let opened = newID()
        guard arrangement.layout.split(target, axis: axis, into: opened) else { return nil }

        if before {
            arrangement.contents[opened] = arrangement.contents[target] ?? tab
            arrangement.contents[target] = placed
            _ = arrangement.layout.setFocus(target)
        } else {
            arrangement.contents[opened] = placed
            if arrangement.contents[target] == nil { arrangement.contents[target] = tab }
        }

        arrangements[tab.id] = arrangement
        persist(tab.id)
        return opened
    }

    func replace(pane: String, of tab: PaneContent, with content: PaneContent, in model: WorkspaceModel) {
        guard var arrangement = arrangements[tab.id] else { return select(content, in: model) }
        guard arrangement.contents[pane] != content, arrangement.canHold(content),
              canAbsorb(content) else { return }

        arrangement.contents[pane] = content
        _ = arrangement.layout.setFocus(pane)
        arrangements[tab.id] = arrangement

        if let stored = arrangement.stored {
            apply(TabSurgery.settle(stored, root: tab), to: tab, in: model.workspace.id)
        }
        adoptActiveSession(of: selected[model.workspace.id] ?? tab, in: model)
    }

    func replaceConversation(_ previous: SessionID, with replacement: SessionID, in model: WorkspaceModel) {
        let old = PaneContent.chat(previous)
        let new = PaneContent.chat(replacement)
        for arrangement in Array(arrangements.values) {
            guard let stored = arrangement.stored else { continue }
            apply(TabSurgery.replace(old, with: new, in: stored, root: arrangement.root),
                  to: arrangement.root, in: model.workspace.id)
        }
        if selected[model.workspace.id] == old { selected[model.workspace.id] = new }
        if let order = stripOrders[model.workspace.id] {
            stripOrders[model.workspace.id] = order.map { $0 == old ? new : $0 }
            persistStrip(model.workspace.id)
        }
    }

    @discardableResult
    func close(pane: String, in tab: PaneContent, of workspaceID: WorkspaceID) -> Bool {
        guard let stored = arrangements[tab.id]?.stored else { return false }
        let outcome = TabSurgery.closePane(pane, in: stored, root: tab)
        guard outcome != .unchanged else { return false }
        apply(outcome, to: tab, in: workspaceID)
        return true
    }

    @discardableResult
    func move(
        pane: String, beside target: String, axis: SplitAxis, before: Bool,
        in tab: PaneContent, of model: WorkspaceModel
    ) -> Bool {
        guard var arrangement = arrangements[tab.id],
              arrangement.layout.move(pane, beside: target, axis: axis, before: before)
        else { return false }

        arrangements[tab.id] = arrangement
        persist(tab.id)
        adoptActiveSession(of: tab, in: model)
        return true
    }

    @discardableResult
    func exchange(
        pane: String, with other: String, in tab: PaneContent, of model: WorkspaceModel
    ) -> Bool {
        guard var arrangement = arrangements[tab.id],
              arrangement.layout.exchange(pane, with: other) else { return false }

        arrangements[tab.id] = arrangement
        persist(tab.id)
        adoptActiveSession(of: tab, in: model)
        return true
    }

    func setRatio(_ ratio: Double, at path: [Int], in tab: PaneContent) {
        guard var arrangement = arrangements[tab.id],
              arrangement.layout.setRatio(ratio, at: path) else { return }
        arrangements[tab.id] = arrangement
    }

    func persistRatio(in tab: PaneContent) {
        persist(tab.id)
    }

    func forget(_ content: PaneContent, workspaceID: WorkspaceID) {
        for arrangement in arrangements.values {
            guard let stored = arrangement.stored else { continue }
            let outcome = TabSurgery.remove(content, from: stored, root: arrangement.root)
            apply(outcome, to: arrangement.root, in: workspaceID)
        }
        if selected[workspaceID] == content { selected[workspaceID] = nil }
    }

    func reconcile(in model: WorkspaceModel) {
        let workspaceID = model.workspace.id
        let tabs = CenterTabStore.shared

        var stored: [PaneContent: StoredPaneArrangement] = [:]
        for arrangement in arrangements.values {
            stored[arrangement.root] = arrangement.stored
        }

        let dead = TabReconciliation.dead(
            in: stored,
            sessions: model.hasReadSessions ? model.sessions.map(\.id) : nil,
            tools: tabs.hasReadTabs(for: workspaceID) ? tabs.tabs(for: workspaceID).map(\.id) : nil
        )
        for content in dead {
            forget(content, workspaceID: workspaceID)
        }
    }

    private func apply(_ outcome: TabSurgery.Outcome, to tab: PaneContent, in workspaceID: WorkspaceID) {
        switch outcome {
        case .unchanged:
            return

        case .updated(let root, let stored):
            guard let arrangement = Arrangement(root: root, stored: stored) else { return }
            arrangements[root.id] = arrangement
            persist(root.id)
            if root != tab {
                arrangements[tab.id] = nil
                UserDefaults.standard.removeObject(forKey: TabDefaults.tabKey(tab.id))
                if selected[workspaceID] == tab { selected[workspaceID] = root }
            }

        case .dissolved(let remaining):
            arrangements[tab.id] = nil
            UserDefaults.standard.removeObject(forKey: TabDefaults.tabKey(tab.id))
            if selected[workspaceID] == tab { selected[workspaceID] = remaining }
        }
    }

    private func persist(_ rootID: String) {
        let defaults = UserDefaults.standard
        let key = TabDefaults.tabKey(rootID)

        guard let arrangement = arrangements[rootID], arrangement.layout.paneCount > 1,
              let data = arrangement.stored?.encoded else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
