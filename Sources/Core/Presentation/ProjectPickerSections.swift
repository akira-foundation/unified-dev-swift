import Foundation

public struct ProjectPickerSection: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable {
        case recent
        case all
    }

    public let kind: Kind
    public let projects: [Repo]

    public var id: String { kind.rawValue }

    public var title: String {
        switch kind {
        case .recent: "Recent"
        case .all: "All"
        }
    }
}

public enum ProjectPickerSections {
    public static func build(repos: [Repo], activity: [RepoID: Date]) -> [ProjectPickerSection] {
        guard !repos.isEmpty else { return [] }

        let byName = repos.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return [
            ProjectPickerSection(kind: .recent, projects: RecentProjects.ordered(repos, activity: activity)),
            ProjectPickerSection(kind: .all, projects: byName),
        ].filter { !$0.projects.isEmpty }
    }

    public static func offersAChoice(_ sections: [ProjectPickerSection]) -> Bool {
        all(in: sections).count > 1
    }

    public static func all(in sections: [ProjectPickerSection]) -> [Repo] {
        sections.first { $0.kind == .all }?.projects ?? []
    }
}
