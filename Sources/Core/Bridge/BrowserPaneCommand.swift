import Foundation

public enum BrowserPaneCommand: Sendable, Equatable {
    case read(Int?)
    case reload(Int?)
    case go(Int?, String)
    case screenshot(Int?)
    case scroll(Int?, BrowserScroll)
    case text(Int?)

    public var approvedAddress: String? {
        guard case .go(_, let address) = self else { return nil }
        return address
    }

    public var readsPage: Bool {
        switch self {
        case .read, .reload, .go: false
        case .screenshot, .scroll, .text: true
        }
    }

    public var toolName: String {
        switch self {
        case .read: BrowserPaneToolName.read
        case .reload: BrowserPaneToolName.reload
        case .go: BrowserPaneToolName.go
        case .screenshot: BrowserPaneToolName.screenshot
        case .scroll: BrowserPaneToolName.scroll
        case .text: BrowserPaneToolName.text
        }
    }

    public var number: Int? {
        switch self {
        case .read(let number), .reload(let number), .go(let number, _),
             .screenshot(let number), .scroll(let number, _), .text(let number):
            number
        }
    }
}

public enum BrowserPaneAnswer: Sendable, Equatable {
    case told(String)
    case reported(JSONValue)
    case pictured(Data, String)
    case refused(String)
}

public typealias BrowserPaneCommanding =
    @Sendable (BrowserPaneCommand, WorkspaceID) async -> BrowserPaneAnswer

public enum BrowserPaneChoice {
    public static func choose(
        number: Int?, among browsers: [BrowserPaneReport], tool: String
    ) -> Result<BrowserPaneReport, PaneRefusal> {
        guard !browsers.isEmpty else {
            return .failure(
                PaneRefusal(
                    "There is no browser open in this workspace, so \(tool) has nothing to look "
                        + "at. Open one with pane_open, or call pane_list to see what is open."
                )
            )
        }

        guard let number else {
            guard browsers.count == 1 else {
                return .failure(
                    PaneRefusal(
                        "There are \(browsers.count) browsers open, so \(tool) needs a 'browser' "
                            + "number to say which: \(list(browsers))."
                    )
                )
            }
            return .success(browsers[0])
        }

        guard let found = browsers.first(where: { $0.number == number }) else {
            return .failure(
                PaneRefusal(
                    "There is no browser \(number) in this workspace. The ones that are open are "
                        + "\(list(browsers)). The numbers change when a tab is closed, so call "
                        + "pane_list again."
                )
            )
        }
        return .success(found)
    }

    private static func list(_ browsers: [BrowserPaneReport]) -> String {
        browsers.map { "\($0.number) on \($0.address.isEmpty ? "no page yet" : $0.address)" }
            .joined(separator: ", ")
    }
}

public enum BrowserPaneToolName {
    public static let read = "browser_read"
    public static let reload = "browser_reload"
    public static let go = "browser_go"
    public static let screenshot = "browser_screenshot"
    public static let scroll = "browser_scroll"
    public static let text = "browser_text"
}
