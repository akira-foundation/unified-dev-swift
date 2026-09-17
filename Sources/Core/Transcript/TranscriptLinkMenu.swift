import Foundation

public enum TranscriptLinkTarget: Sendable, Hashable {
    case externalBrowser
    case browserTab
    case split(SplitAxis)
}

public struct TranscriptLinkItem: Sendable, Hashable, Identifiable {
    public var title: String
    public var target: TranscriptLinkTarget

    public var id: TranscriptLinkTarget { target }

    public init(title: String, target: TranscriptLinkTarget) {
        self.title = title
        self.target = target
    }
}

public enum TranscriptLinkPlacement: Sendable, Hashable, CaseIterable {
    case detached
    case column
    case pane
}

public enum TranscriptLinkMenu {
    public static func items(
        for url: URL, placement: TranscriptLinkPlacement
    ) -> [TranscriptLinkItem] {
        var items = [TranscriptLinkItem(title: "Open in External Browser", target: .externalBrowser)]

        guard placement != .detached, BrowserAddress.shows(url) else { return items }
        items.append(TranscriptLinkItem(title: "Open in Browser Tab", target: .browserTab))

        guard placement == .pane else { return items }
        items.append(TranscriptLinkItem(title: "Open in Split Right", target: .split(.horizontal)))
        items.append(TranscriptLinkItem(title: "Open in Split Down", target: .split(.vertical)))
        return items
    }
}
