import Foundation

public enum LinkOpening {
    public static let settingKey = "links.opensInBuiltInBrowser"

    public static let isOnByDefault = true

    public static let settingTitle = "Open links in the built-in browser"

    public static let settingDetail =
        "Links in chats, terminals and previews open in a tab of the workspace. Control-click a chat link, "
        + "or Shift-Command-click a terminal link, to use your default browser."

    public static func target(
        for url: URL,
        placement: TranscriptLinkPlacement,
        isEnabled: Bool,
        asksForExternal: Bool = false
    ) -> TranscriptLinkTarget {
        guard isEnabled, !asksForExternal, placement != .detached, BrowserAddress.shows(url) else {
            return .externalBrowser
        }
        return .browserTab
    }

    public static func tab(showing address: String, among addresses: [String]) -> Int? {
        let wanted = pageIdentity(address)
        return addresses.lastIndex { !$0.isEmpty && pageIdentity($0) == wanted }
    }

    private static func pageIdentity(_ address: String) -> String {
        address.hasSuffix("/") ? String(address.dropLast()) : address
    }
}
