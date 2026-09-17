import Foundation

public enum TabSet {
    public static func tabbable(_ sessions: [Session]) -> [SessionID] {
        sessions.filter { $0.parentSessionID == nil && $0.sideConversationParentID == nil }.map(\.id)
    }

    public static func entries(
        sessions: [SessionID],
        tools: [String],
        claimed: Set<PaneContent> = []
    ) -> [PaneContent] {
        all(sessions: sessions, tools: tools).filter { !claimed.contains($0) }
    }

    public static func all(sessions: [SessionID], tools: [String]) -> [PaneContent] {
        sessions.map(PaneContent.chat) + tools.map(PaneContent.tool)
    }
}
