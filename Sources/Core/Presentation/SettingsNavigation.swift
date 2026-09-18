import Foundation

public struct SettingsNavigation<Page: Hashable & Sendable>: Equatable, Sendable {
    public private(set) var current: Page
    public private(set) var history: [Page] = []
    public private(set) var future: [Page] = []

    public init(current: Page) {
        self.current = current
    }

    public var canGoBack: Bool { !history.isEmpty }
    public var canGoForward: Bool { !future.isEmpty }

    public mutating func select(_ page: Page) {
        guard page != current else { return }
        history.append(current)
        future.removeAll()
        current = page
    }

    public mutating func goBack() {
        guard let previous = history.popLast() else { return }
        future.append(current)
        current = previous
    }

    public mutating func goForward() {
        guard let next = future.popLast() else { return }
        history.append(current)
        current = next
    }
}

public struct SettingsSidebarSection<Page: Hashable & Sendable>: Equatable, Sendable, Identifiable {
    public var title: String?
    public var pages: [Page]

    public init(_ title: String? = nil, pages: [Page]) {
        self.title = title
        self.pages = pages
    }

    public var id: String { title ?? "" }

    public static func matching(
        _ sections: [SettingsSidebarSection],
        query: String,
        title: (Page) -> String
    ) -> [SettingsSidebarSection] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            let pages = section.pages.filter { title($0).localizedCaseInsensitiveContains(query) }
            return pages.isEmpty ? nil : SettingsSidebarSection(section.title, pages: pages)
        }
    }
}
