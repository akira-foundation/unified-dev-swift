import Foundation

public extension PreviewScenario {
    var recentProblems: [String] {
        var problems: [String] = []
        var seen = Set<String>()
        for name in recentFolders {
            if !Self.isFolderName(name) {
                problems.append("recent folder \"\(name)\" is not a plain folder name")
            }
            if !seen.insert(name.lowercased()).inserted {
                problems.append("recent folder \"\(name)\" is named twice")
            }
            guard !known.contains(name) else { continue }
            problems.append(
                "recent folder \"\(name)\" is not a project, a loose repository or a loose folder "
                    + "of this scenario"
            )
        }
        return problems
    }

    private var known: Set<String> {
        Set(projects.map(\.name) + looseRepositories + looseFolders)
    }
}
