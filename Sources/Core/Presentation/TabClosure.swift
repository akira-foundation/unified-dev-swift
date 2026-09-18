import Foundation

public enum TabClosure {
    public static func selectionAfterClosing<ID: Equatable>(
        _ id: ID, selected: ID?, tabs: [ID]
    ) -> ID? {
        guard selected == id else { return selected }
        guard let index = tabs.firstIndex(of: id) else { return nil }
        if index > 0 { return tabs[index - 1] }
        return tabs.dropFirst().first
    }

    public static func target(
        selectedTab: PaneContent?, focusedPaneContent: PaneContent?
    ) -> PaneContent? {
        guard let selectedTab else { return nil }
        return focusedPaneContent ?? selectedTab
    }
}
