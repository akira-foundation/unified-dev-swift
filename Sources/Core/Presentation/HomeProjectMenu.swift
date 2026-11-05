import Foundation

public struct HomeProjectMenu: Equatable, Sendable {
    public var visible: [Repo]
    public var hidden: [Repo]
    public var moves: [Move]

    public struct Move: Identifiable, Equatable, Sendable {
        public let repo: Repo
        public let targets: [Profile]
        public var id: RepoID { repo.id }
    }

    public init(_ repos: [Repo], profiles: [Profile] = []) {
        let sorted = repos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let visible = sorted.filter { !$0.hidden }
        self.visible = visible
        let hidden = sorted.filter(\.hidden)
        self.hidden = hidden
        moves = (visible + hidden).compactMap { repo in
            let targets = ProfileMove.targets(for: repo, among: profiles)
            return targets.isEmpty ? nil : Move(repo: repo, targets: targets)
        }
    }
}
