import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class CenterTabStore {
    static let shared = CenterTabStore()

    private(set) var tabsByWorkspace: [WorkspaceID: [CenterTab]] = [:]

    @ObservationIgnored private var unreadable: Set<WorkspaceID> = []

    @ObservationIgnored private var browsers: [String: BrowserSession] = [:]

    private init() {}

    func tabs(for workspaceID: WorkspaceID) -> [CenterTab] {
        tabsByWorkspace[workspaceID] ?? []
    }

    func hasReadTabs(for workspaceID: WorkspaceID) -> Bool {
        tabsByWorkspace[workspaceID] != nil && !unreadable.contains(workspaceID)
    }

    func review(for workspaceID: WorkspaceID) -> CenterTab? {
        tabs(for: workspaceID).first { $0.kind == .review && !$0.isPinnedToPath }
    }

    func notes(for workspaceID: WorkspaceID) -> CenterTab? {
        tabs(for: workspaceID).first { $0.kind == .notes }
    }

    func title(of content: PaneContent, in model: WorkspaceModel) -> String {
        switch content {
        case .chat(let sessionID):
            let title = model.sessions.first { $0.id == sessionID }?.title ?? ""
            return title.isEmpty ? PaneNaming.untitledChat : title
        case .tool(let id):
            guard let tab = tabs(for: model.workspace.id).first(where: { $0.id == id }) else {
                return PaneNaming.missingTab
            }
            return displayTitle(of: tab, in: model)
        }
    }

    func displayTitle(of tab: CenterTab, in model: WorkspaceModel) -> String {
        switch tab.kind {
        case .browser:
            return BrowserTabTitle.title(
                page: tab.pageTitle, address: tab.url, fallback: tab.title, isNamed: tab.isNamed
            )
        case .review:
            guard !tab.showsAllFiles, !tab.path.isEmpty else { return tab.title }
            if tab.isPinnedToPath { return (tab.path as NSString).lastPathComponent }
            if model.changedFiles.contains(where: { $0.path == tab.path }) { return tab.title }
            return (tab.path as NSString).lastPathComponent
        case .terminal, .notes:
            return tab.title
        }
    }

    func load(workspaceID: WorkspaceID) {
        guard tabsByWorkspace[workspaceID] == nil else { return }
        guard let restored = Self.restore(workspaceID: workspaceID) else {
            unreadable.insert(workspaceID)
            tabsByWorkspace[workspaceID] = []
            return
        }
        tabsByWorkspace[workspaceID] = restored
    }

    @discardableResult
    func add(
        kind: CenterTab.Kind, workspaceID: WorkspaceID, url: String = "", title: String? = nil,
        directory: String = "", agentSessionID: SessionID? = nil, runScriptID: String? = nil
    ) -> CenterTab {
        var tabs = tabs(for: workspaceID)
        let tab = CenterTab(
            workspaceID: workspaceID,
            kind: kind,
            title: title ?? Self.nextTitle(for: kind, in: tabs),
            url: url,
            isNamed: title != nil,
            directory: directory,
            agentSessionID: agentSessionID,
            runScriptID: runScriptID
        )
        tabs.append(tab)
        apply(tabs, to: workspaceID)
        return tab
    }

    func terminal(for sessionID: SessionID, in workspaceID: WorkspaceID) -> CenterTab? {
        tabs(for: workspaceID).first { $0.kind == .terminal && $0.agentSessionID == sessionID }
    }

    func terminalTabIDs(for workspaceID: WorkspaceID) -> [String] {
        let tabs = tabsByWorkspace[workspaceID] ?? Self.restore(workspaceID: workspaceID) ?? []
        return tabs.filter { $0.kind == .terminal }.map(\.id)
    }

    func adoptTerminalTabs(from store: Store?) async {
        guard let store,
              let rows = try? await store.terminalTabs(),
              !rows.isEmpty,
              let workspaces = try? await store.workspaces()
        else { return }

        let present = Set(workspaces.map(\.id))
        var rowsByWorkspace: [WorkspaceID: [TerminalTab]] = [:]
        for row in rows where present.contains(row.workspaceID) {
            rowsByWorkspace[row.workspaceID, default: []].append(row)
        }
        guard !rowsByWorkspace.isEmpty else { return }

        let live = await TerminalSessionStore.shared.liveSessions(store: store).map(Set.init)

        for (workspaceID, rows) in rowsByWorkspace {
            var tabs = tabsByWorkspace[workspaceID] ?? Self.restore(workspaceID: workspaceID) ?? []
            let known = Set(tabs.map(\.id))

            for row in rows where !known.contains(row.id.rawValue) {
                guard Self.isWorthKeeping(row, in: workspaceID, live: live) else { continue }
                tabs.append(CenterTab(
                    id: row.id.rawValue, workspaceID: workspaceID, kind: .terminal, title: row.title
                ))
            }
            apply(tabs, to: workspaceID)

            for row in rows { try? await store.deleteTerminalTab(id: row.id) }
        }
    }

    private static func isWorthKeeping(
        _ row: TerminalTab, in workspaceID: WorkspaceID, live: Set<String>?
    ) -> Bool {
        if !isDefaultTitle(row.title) { return true }

        let panes = TerminalSplitStore.shared.panes(of: row.id.rawValue)
        if panes.count > 1 { return true }

        guard let live else { return true }
        return panes.contains {
            live.contains(TmuxSessions.sessionName(workspaceID: workspaceID, paneID: $0))
        }
    }

    private static func isDefaultTitle(_ title: String) -> Bool {
        PaneNaming.isDefaultTitle(title, base: PaneNaming.terminal)
    }

    func reorder(_ ids: [String], in workspaceID: WorkspaceID) {
        let open = tabs(for: workspaceID)
        let byID = Dictionary(open.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = ids.compactMap { byID[$0] }
        guard ordered.count == open.count else { return }
        apply(ordered, to: workspaceID)
    }

    func rename(_ tab: CenterTab, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(tab) {
            $0.title = trimmed
            $0.isNamed = true
        }
    }

    @discardableResult
    func showReview(path: String, workspaceID: WorkspaceID) -> CenterTab {
        if let existing = review(for: workspaceID) {
            if existing.path != path || existing.showsAllFiles {
                update(existing) {
                    $0.path = path
                    $0.reviewNavigationRevision += 1
                }
            }
            return review(for: workspaceID) ?? existing
        }
        var tabs = tabs(for: workspaceID)
        let tab = CenterTab(
            workspaceID: workspaceID,
            kind: .review,
            title: CenterTab.reviewTitle,
            path: path
        )
        tabs.append(tab)
        apply(tabs, to: workspaceID)
        return tab
    }

    func setShowsAllFiles(_ showsAllFiles: Bool, for tab: CenterTab) {
        guard tab.kind == .review, !tab.isPinnedToPath else { return }
        update(tab) { $0.showsAllFiles = showsAllFiles }
    }

    @discardableResult
    func openPinnedReview(path: String, workspaceID: WorkspaceID) -> CenterTab {
        if let existing = tabs(for: workspaceID).first(
            where: { $0.kind == .review && $0.isPinnedToPath && $0.path == path }
        ) {
            return existing
        }
        var tabs = tabs(for: workspaceID)
        let tab = CenterTab(
            workspaceID: workspaceID,
            kind: .review,
            title: (path as NSString).lastPathComponent,
            path: path,
            isPinnedToPath: true
        )
        tabs.append(tab)
        apply(tabs, to: workspaceID)
        return tab
    }

    @discardableResult
    func showNotes(workspaceID: WorkspaceID) -> CenterTab {
        if let existing = notes(for: workspaceID) { return existing }
        var tabs = tabs(for: workspaceID)
        let tab = CenterTab(workspaceID: workspaceID, kind: .notes, title: CenterTab.notesTitle)
        tabs.append(tab)
        apply(tabs, to: workspaceID)
        return tab
    }

    func setURL(_ url: String, for tab: CenterTab) {
        guard !url.isEmpty else { return }
        setPage(BrowserTabTitle.BrowserPage(address: url), for: tab)
    }

    func setPage(_ page: BrowserTabTitle.BrowserPage, for tab: CenterTab) {
        let showing = BrowserTabTitle.BrowserPage(address: tab.url, title: tab.pageTitle)
        let next = BrowserTabTitle.advance(from: showing, to: page)
        guard next != showing else { return }
        update(tab) {
            $0.url = next.address
            $0.pageTitle = next.title
        }
    }

    func close(_ tab: CenterTab) async {
        apply(tabs(for: tab.workspaceID).filter { $0.id != tab.id }, to: tab.workspaceID)
        WorkspaceTabsStore.shared.forget(.tool(tab.id), workspaceID: tab.workspaceID)

        switch tab.kind {
        case .browser:
            browsers[tab.id]?.stop()
            browsers[tab.id] = nil
        case .terminal:
            stopShell(for: tab)
        case .review:
            break
        case .notes:
            break
        }
    }

    func browser(for tab: CenterTab, root: String = "") -> BrowserSession {
        if let existing = browsers[tab.id] { return existing }
        let session = BrowserSession(url: tab.url, root: root)
        browsers[tab.id] = session
        return session
    }

    func liveBrowser(for tab: CenterTab) -> BrowserSession? {
        browsers[tab.id]
    }

    private func stopShell(for tab: CenterTab) {
        TerminalSessionStore.shared.closePanes(of: tab.id)
        if let sessionID = tab.agentSessionID {
            try? AgentKind.removeInteractiveLaunch(sessionID: sessionID)
        }
    }

    private func update(_ tab: CenterTab, _ change: (inout CenterTab) -> Void) {
        var tabs = tabs(for: tab.workspaceID)
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        change(&tabs[index])
        apply(tabs, to: tab.workspaceID)
    }

    private func apply(_ tabs: [CenterTab], to workspaceID: WorkspaceID) {
        unreadable.remove(workspaceID)
        tabsByWorkspace[workspaceID] = tabs
        Self.persist(tabs, workspaceID: workspaceID)
    }

    private static func key(_ workspaceID: WorkspaceID) -> String { TabDefaults.tabListKey(workspaceID) }

    private static func persist(_ tabs: [CenterTab], workspaceID: WorkspaceID) {
        let defaults = UserDefaults.standard
        guard !tabs.isEmpty else {
            defaults.removeObject(forKey: key(workspaceID))
            return
        }
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        defaults.set(data, forKey: key(workspaceID))
    }

    private static func restore(workspaceID: WorkspaceID) -> [CenterTab]? {
        guard let data = UserDefaults.standard.data(forKey: key(workspaceID)) else { return [] }
        return try? JSONDecoder().decode([CenterTab].self, from: data)
    }

    private static func nextTitle(for kind: CenterTab.Kind, in tabs: [CenterTab]) -> String {
        let base = switch kind {
        case .terminal: PaneNaming.terminal
        case .browser: PaneNaming.browser
        case .review: CenterTab.reviewTitle
        case .notes: CenterTab.notesTitle
        }
        return PaneNaming.nextTitle(base: base, taken: tabs.filter { $0.kind == kind }.map(\.title))
    }
}
