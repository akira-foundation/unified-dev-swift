import Foundation

public enum BrowserTabTitle {
    public static let limit = 80

    public static func tidy(_ raw: String?) -> String {
        guard let raw else { return "" }

        let flattened = String(String.UnicodeScalarView(raw.unicodeScalars.map {
            $0.value < 0x20 || $0.value == 0x7F ? " " : $0
        }))

        let collapsed = flattened
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > limit else { return collapsed }

        let cut = collapsed.prefix(limit)
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > limit / 2 {
            return String(cut[..<space]) + "…"
        }
        return String(cut) + "…"
    }

    public static func host(of address: String) -> String? {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host(), !host.isEmpty
        else { return nil }

        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        guard !bare.isEmpty else { return nil }
        guard let port = url.port else { return bare }
        return "\(bare):\(port)"
    }

    public static func survives(navigationFrom old: String, to new: String) -> Bool {
        guard let from = host(of: old), let to = host(of: new) else { return false }
        return from == to
    }

    public struct BrowserPage: Equatable, Sendable {
        public var address: String
        public var title: String

        public init(address: String = "", title: String = "") {
            self.address = address
            self.title = title
        }
    }

    public static func advance(from tab: BrowserPage, to page: BrowserPage) -> BrowserPage {
        let address = page.address.isEmpty ? tab.address : page.address
        let kept = survives(navigationFrom: tab.address, to: address) ? tab.title : ""
        let arrived = tidy(page.title)
        return BrowserPage(address: address, title: arrived.isEmpty ? kept : arrived)
    }

    public static func title(
        page: String, address: String, fallback: String, isNamed: Bool = false
    ) -> String {
        if isNamed { return fallback }

        let page = tidy(page)
        if !page.isEmpty, page != address, host(of: address).map({ page != $0 }) ?? true {
            return page
        }
        return host(of: address) ?? fallback
    }
}
