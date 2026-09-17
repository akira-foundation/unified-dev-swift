import Foundation

public enum TabReconciliation {
    public static func dead(
        in arrangements: [PaneContent: StoredPaneArrangement],
        sessions: [SessionID]?,
        tools: [String]?
    ) -> [PaneContent] {
        let chats = sessions.map { Set($0.map(PaneContent.chat)) }
        let tools = tools.map { Set($0.map(PaneContent.tool)) }

        var dead: Set<PaneContent> = []
        for root in (chats ?? []).union(tools ?? []) {
            guard let stored = arrangements[root],
                  let layout = SplitLayout(encoded: stored.layout) else { continue }
            for pane in layout.panes {
                guard let content = stored.contents[pane] else { continue }
                let known = content.isChat ? chats : tools
                guard let known, !known.contains(content) else { continue }
                dead.insert(content)
            }
        }
        return dead.sorted { $0.id < $1.id }
    }
}
