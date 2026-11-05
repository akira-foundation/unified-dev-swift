import Foundation

public enum CanvasCommentRouting {
    public static func target(
        besideChat: SessionID?, shownBy: SessionID?, active: SessionID?, accepting accepts: (SessionID) -> Bool = { _ in true }
    ) -> SessionID? {
        [besideChat, shownBy, active].compactMap(\.self).first(where: accepts)
    }

    public static func chatBeside(_ canvas: PaneContent, in tabs: [PaneSplitAnchor.Tab]) -> SessionID? {
        guard let tab = tabs.first(where: { $0.contents.values.contains(canvas) }) else { return nil }
        let panes = [tab.layout.focus] + tab.layout.panes.filter { $0 != tab.layout.focus }
        for pane in panes {
            if case .chat(let session)? = tab.contents[pane] { return session }
        }
        return nil
    }
}
