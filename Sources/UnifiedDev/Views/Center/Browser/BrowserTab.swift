import SwiftUI
import Core

@MainActor
enum BrowserTab {
    static var opensLinksInside: Bool {
        UserDefaults.standard.bool(forKey: LinkOpening.settingKey)
    }

    static func staysInside(_ url: URL, asksForExternal: Bool = false) -> Bool {
        LinkOpening.target(
            for: url, placement: .column, isEnabled: opensLinksInside, asksForExternal: asksForExternal
        ) == .browserTab
    }

    static func follow(_ url: URL, in model: WorkspaceModel, asksForExternal: Bool) -> Bool {
        guard staysInside(url, asksForExternal: asksForExternal) else { return false }
        open(url, in: model)
        return true
    }

    static func canOpen(_ url: URL) -> Bool {
        BrowserAddress.shows(url)
    }

    static func placement(of pane: String?, in model: WorkspaceModel?) -> TranscriptLinkPlacement {
        guard let model else { return .detached }
        guard let pane, let tab = WorkspaceTabsStore.shared.selectedTab(in: model),
              WorkspaceTabsStore.shared.layout(of: tab).contains(pane) else { return .column }
        return .pane
    }

    static func split(_ url: URL, in model: WorkspaceModel, pane: String, axis: SplitAxis) {
        guard canOpen(url) else { return }
        let tabs = WorkspaceTabsStore.shared
        guard let tab = tabs.selectedTab(in: model), tabs.layout(of: tab).contains(pane) else {
            return
        }
        NewPane.open(.browser, in: model, url: url.absoluteString) { content in
            tabs.split(tab: tab, pane: pane, axis: axis, showing: content)
        }
    }

    static func openWindow(_ url: URL, in model: WorkspaceModel) {
        guard canOpen(url) else { return }
        let tab = CenterTabStore.shared.add(
            kind: .browser, workspaceID: model.workspace.id, url: url.absoluteString
        )
        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model)
    }

    static func open(_ url: URL, in model: WorkspaceModel) {
        guard canOpen(url) else { return }
        show(url.absoluteString, in: model)
    }

    static func openFile(_ path: String, in model: WorkspaceModel) {
        guard let address = LocalPage.address(forFile: path) else { return }
        show(address, in: model, reloading: true)
    }

    static func splitFile(_ path: String, in model: WorkspaceModel, axis: SplitAxis) {
        guard let address = LocalPage.address(forFile: path) else { return }
        let tabs = WorkspaceTabsStore.shared
        guard let tab = tabs.selectedTab(in: model) else { return }
        let pane = tabs.focusedPane(of: tab)
        NewPane.open(.browser, in: model, url: address) { content in
            tabs.split(tab: tab, pane: pane, axis: axis, showing: content)
        }
    }

    private static func show(_ address: String, in model: WorkspaceModel, reloading: Bool = false) {
        let tabs = CenterTabStore.shared
        let open = tabs.tabs(for: model.workspace.id).filter { $0.kind == .browser }
        let addresses = open.map { tabs.liveBrowser(for: $0)?.currentURL?.absoluteString ?? $0.url }
        let tab: CenterTab
        if let index = LinkOpening.tab(showing: address, among: addresses) {
            tab = open[index]
            if reloading || tabs.liveBrowser(for: tab)?.failure != nil { tabs.browser(for: tab, root: model.workspace.path).load(address) }
        } else {
            tab = tabs.add(kind: .browser, workspaceID: model.workspace.id, url: address)
        }

        WorkspaceTabsStore.shared.reveal(.tool(tab.id), in: model)
    }
}
