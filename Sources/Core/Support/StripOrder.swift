import Foundation

public enum StripOrder {
    public static func entries(
        sessions: [SessionID],
        tools: [String],
        claimed: Set<PaneContent> = [],
        stored: [PaneContent] = []
    ) -> [PaneContent] {
        let fallback = TabSet.entries(sessions: sessions, tools: tools, claimed: claimed)
        guard !stored.isEmpty else { return fallback }

        let present = Set(fallback)
        var seen: Set<PaneContent> = []
        let known = stored.filter { present.contains($0) && seen.insert($0).inserted }
        let unknown = fallback.filter { !seen.contains($0) }
        return known + unknown
    }

    public static func rewritten(
        _ drawn: [PaneContent],
        sessions: [SessionID],
        tools: [String],
        stored: [PaneContent]
    ) -> [PaneContent]? {
        let everything = TabSet.all(sessions: sessions, tools: tools)
        let existing = Set(everything)

        var seen: Set<PaneContent> = []
        let kept = stored.filter { existing.contains($0) && seen.insert($0).inserted }
        let base = kept + everything.filter { !seen.contains($0) }

        let order = TabReorder.apply(drawn, to: base) ?? base
        return order == stored ? nil : order
    }
}
