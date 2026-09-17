import Foundation

public enum TabClosure {
    public static func target(
        selectedTab: PaneContent?, focusedPaneContent: PaneContent?
    ) -> PaneContent? {
        guard let selectedTab else { return nil }
        return focusedPaneContent ?? selectedTab
    }
}
