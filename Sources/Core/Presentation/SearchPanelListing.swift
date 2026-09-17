import Foundation

public struct SearchPanelSection: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String?
    public var rows: [SearchPanelRow]

    public init(id: String, title: String?, rows: [SearchPanelRow]) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}

public struct SearchPanelListing: Equatable, Sendable {
    public var sections: [SearchPanelSection]
    public var rows: [SearchPanelRow]
    public var counts: HomeScopeCounts
    public var isSearching: Bool
    public var summary: String?
    public var nothing: SearchPanelNothing?

    public init(
        sections: [SearchPanelSection],
        counts: HomeScopeCounts = HomeScopeCounts(),
        isSearching: Bool = false,
        summary: String? = nil,
        nothing: SearchPanelNothing? = nil
    ) {
        self.sections = sections
        self.rows = sections.flatMap(\.rows)
        self.counts = counts
        self.isSearching = isSearching
        self.summary = summary ?? SearchPanelSummary.rows(self.rows.count)
        self.nothing = nothing
    }

    public static let empty = SearchPanelListing(sections: [])

    public var isEmpty: Bool { rows.isEmpty }

    public func row(at index: Int?) -> SearchPanelRow? {
        guard let index, rows.indices.contains(index) else { return nil }
        return rows[index]
    }
}
