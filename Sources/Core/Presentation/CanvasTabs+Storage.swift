import Foundation

public struct StoredCanvasTab<Tab: Codable>: Codable {
    public let index: Int
    public let tab: Tab

    public init(index: Int, tab: Tab) {
        self.index = index
        self.tab = tab
    }
}

public struct CanvasTabsSplit<Tab: CanvasTabValue & Codable> {
    public let list: [Tab]
    public let canvas: StoredCanvasTab<Tab>?
}

extension CanvasTabs {
    public static func storageKey(_ workspaceID: WorkspaceID) -> String {
        TabDefaults.tabListKey(workspaceID) + ".canvas"
    }

    public static func split<Tab: CanvasTabValue & Codable>(_ tabs: [Tab]) -> CanvasTabsSplit<Tab> {
        guard let index = tabs.firstIndex(where: { $0.kind == .canvas }) else {
            return CanvasTabsSplit(list: tabs, canvas: nil)
        }
        return CanvasTabsSplit(
            list: tabs.filter { $0.kind != .canvas },
            canvas: StoredCanvasTab(index: index, tab: tabs[index])
        )
    }

    public static func merge<Tab: CanvasTabValue & Codable>(
        _ list: [Tab], canvas: StoredCanvasTab<Tab>?
    ) -> [Tab] {
        guard let canvas, canvas.tab.kind == .canvas else { return list }
        var tabs = list.filter { $0.kind != .canvas }
        tabs.insert(canvas.tab, at: min(max(canvas.index, 0), tabs.count))
        return tabs
    }
}
