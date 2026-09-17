import Foundation

public struct SearchPanelReach: Equatable, Sendable {
    public var archived: Bool

    public var hidden: Bool

    public static let live = SearchPanelReach()

    public init(archived: Bool = false, hidden: Bool = false) {
        self.archived = archived
        self.hidden = hidden
    }

    public static func reading(scope: HomeScope, showsHiddenProjects: Bool) -> SearchPanelReach {
        SearchPanelReach(archived: scope == .archived, hidden: showsHiddenProjects)
    }

    public func projects(_ repos: [Repo]) -> [Repo] {
        hidden ? repos : repos.filter { !$0.hidden }
    }
}
