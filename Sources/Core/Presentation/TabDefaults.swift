import Foundation

public enum TabDefaults {
    public static let legacyCentrePrefix = "center.panes."

    public static let tabPrefix = "center.tab."

    public static func tabKey(_ rootContentID: String) -> String { tabPrefix + rootContentID }

    public static func tabKey(root: PaneContent) -> String { tabKey(root.id) }

    public static let tabListPrefix = "center.tabs."

    public static func tabListKey(_ workspaceID: WorkspaceID) -> String {
        tabListPrefix + workspaceID.rawValue
    }

    public static let stripPrefix = "center.strip."

    public static func stripKey(_ workspaceID: WorkspaceID) -> String {
        stripPrefix + workspaceID.rawValue
    }

    public static let splitPrefix = "terminal.split."

    public static func splitKey(_ tabID: String) -> String { splitPrefix + tabID }
}
