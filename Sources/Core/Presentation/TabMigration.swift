import Foundation

public enum TabMigration {
    public struct CompositeTab: Sendable, Equatable {
        public var root: PaneContent
        public var stored: StoredPaneArrangement

        public var key: String { TabDefaults.tabKey(root: root) }
    }

    public static func invert(_ old: StoredPaneArrangement) -> CompositeTab? {
        guard var layout = SplitLayout(encoded: old.layout) else { return nil }

        for pane in layout.panes where old.contents[pane] == nil {
            _ = layout.close(pane)
        }

        var seenTools: Set<String> = []
        for pane in layout.panes {
            guard case .tool(let tool)? = old.contents[pane] else { continue }
            if seenTools.insert(tool).inserted { continue }
            _ = layout.close(pane)
        }

        guard layout.paneCount > 1, let encoded = layout.encoded else { return nil }

        let order = layout.panes
        let held = order.compactMap { old.contents[$0] }
        guard let root = held.first(where: \.isChat) ?? held.first else { return nil }

        let contents = old.contents.filter { order.contains($0.key) }
        return CompositeTab(
            root: root, stored: StoredPaneArrangement(layout: encoded, contents: contents)
        )
    }

    @discardableResult
    public static func migrateAll(
        in defaults: UserDefaults, keys: some Sequence<String>
    ) -> [CompositeTab] {
        keys
            .filter { $0.hasPrefix(TabDefaults.legacyCentrePrefix) }
            .sorted()
            .compactMap { migrate(legacyKey: $0, in: defaults) }
    }

    @discardableResult
    public static func migrate(workspaceID: WorkspaceID, in defaults: UserDefaults) -> CompositeTab? {
        migrate(legacyKey: TabDefaults.legacyCentrePrefix + workspaceID.rawValue, in: defaults)
    }

    private static func migrate(legacyKey: String, in defaults: UserDefaults) -> CompositeTab? {
        guard let data = defaults.data(forKey: legacyKey) else { return nil }

        guard let old = StoredPaneArrangement(decoding: data),
              let tab = invert(old), let encoded = tab.stored.encoded else {
            defaults.removeObject(forKey: legacyKey)
            return nil
        }

        defaults.set(encoded, forKey: tab.key)
        defaults.removeObject(forKey: legacyKey)
        return tab
    }
}
