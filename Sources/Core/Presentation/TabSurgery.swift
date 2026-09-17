import Foundation

public enum TabSurgery {
    public enum Outcome: Sendable, Equatable {
        case unchanged

        case updated(root: PaneContent, stored: StoredPaneArrangement)

        case dissolved(remaining: PaneContent?)
    }

    public static func closePane(
        _ pane: String, in stored: StoredPaneArrangement, root: PaneContent
    ) -> Outcome {
        guard var layout = SplitLayout(encoded: stored.layout), layout.contains(pane),
              layout.close(pane) else { return .unchanged }

        var contents = stored.contents
        contents[pane] = nil
        return settle(layout: layout, contents: contents, root: root)
    }

    public static func remove(
        _ content: PaneContent, from stored: StoredPaneArrangement, root: PaneContent
    ) -> Outcome {
        guard var layout = SplitLayout(encoded: stored.layout) else { return .unchanged }
        var contents = stored.contents

        let doomed = layout.panes.filter { contents[$0] == content }
        guard !doomed.isEmpty else { return .unchanged }

        for pane in doomed {
            guard layout.close(pane) else { break }
            contents[pane] = nil
        }
        return settle(layout: layout, contents: contents, root: root)
    }

    public static func replace(
        _ content: PaneContent, with replacement: PaneContent,
        in stored: StoredPaneArrangement, root: PaneContent
    ) -> Outcome {
        guard stored.contents.values.contains(content) else { return .unchanged }
        let next = StoredPaneArrangement(
            layout: stored.layout,
            contents: stored.contents.mapValues { $0 == content ? replacement : $0 }
        )
        return settle(next, root: root == content ? replacement : root)
    }

    public static func settle(_ stored: StoredPaneArrangement, root: PaneContent) -> Outcome {
        guard let layout = SplitLayout(encoded: stored.layout) else { return .unchanged }
        return settle(layout: layout, contents: stored.contents, root: root)
    }

    private static func settle(
        layout: SplitLayout, contents: [String: PaneContent], root: PaneContent
    ) -> Outcome {
        let held = layout.panes.compactMap { contents[$0] }
        guard layout.paneCount > 1, let encoded = layout.encoded else {
            return .dissolved(remaining: held.first)
        }

        let survivors = StoredPaneArrangement(
            layout: encoded, contents: contents.filter { layout.contains($0.key) }
        )
        if held.contains(root) { return .updated(root: root, stored: survivors) }

        guard let refiled = held.first(where: \.isChat) ?? held.first else {
            return .dissolved(remaining: nil)
        }
        return .updated(root: refiled, stored: survivors)
    }
}
