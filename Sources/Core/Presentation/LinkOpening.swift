import Foundation

public enum LinkOpening {
    public static let settingKey = "links.opensInBuiltInBrowser"

    public static let isOnByDefault = true

    public static let settingTitle = "Open links in the built-in browser"

    public static let settingDetail =
        "Links in chats, terminals and previews open in a tab of the workspace. Control-click a chat link, "
        + "or Shift-Command-click a terminal link, to use your default browser. Sign-in pages always open there. "
        + "Agents cannot read or use these tabs unless you share one from its toolbar."

    public static func target(
        for url: URL,
        placement: TranscriptLinkPlacement,
        isEnabled: Bool,
        asksForExternal: Bool = false
    ) -> TranscriptLinkTarget {
        guard isEnabled, !asksForExternal, placement != .detached, BrowserAddress.shows(url),
              !isSignInPage(url) else {
            return .externalBrowser
        }
        return .browserTab
    }

    public struct OpenPane: Equatable, Sendable {
        public var address: String
        public var access: BrowserPaneAccess

        public init(address: String, access: BrowserPaneAccess) {
            self.address = address
            self.access = access
        }
    }

    public static func tab(showing address: String, among panes: [OpenPane]) -> Int? {
        let wanted = pageIdentity(address)
        return panes.lastIndex {
            !$0.access.isOpenToAgents && !$0.address.isEmpty && pageIdentity($0.address) == wanted
        }
    }

    private static let signInSegments: Set<String> = [
        "login", "log-in", "signin", "sign-in", "oauth", "oauth2", "authorize", "sso", "device",
    ]

    private static func isSignInPage(_ url: URL) -> Bool {
        guard !isOnThisMac(url) else { return false }
        return url.pathComponents.contains { signInSegments.contains($0.lowercased()) }
    }

    private static func isOnThisMac(_ url: URL) -> Bool {
        let host = url.host(percentEncoded: false)?.lowercased() ?? ""
        return ["localhost", "127.0.0.1", "0.0.0.0", "::1"].contains(host) || host.hasSuffix(".localhost")
    }

    private static func pageIdentity(_ address: String) -> String {
        address.hasSuffix("/") ? String(address.dropLast()) : address
    }
}
