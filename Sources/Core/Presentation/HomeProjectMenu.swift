import Foundation

public struct HomeProjectMenu: Equatable, Sendable {
    public var visible: [Repo]
    public var hidden: [Repo]

    public init(_ repos: [Repo]) {
        let sorted = repos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        visible = sorted.filter { !$0.hidden }
        hidden = sorted.filter(\.hidden)
    }
}
