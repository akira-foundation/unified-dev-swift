import Foundation

public enum BridgeProjectLookup: Sendable {
    public enum Outcome: Sendable, Equatable {
        case found(Repo)
        case unknown
        case ambiguous([Repo])
    }

    public static func find(_ query: String, in projects: [Repo]) -> Outcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }

        if let byID = projects.first(where: { $0.id.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return .found(byID)
        }

        if let byPath = project(atPath: trimmed, in: projects) { return .found(byPath) }

        let byName = projects.filter { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
        switch byName.count {
        case 0: return .unknown
        case 1: return .found(byName[0])
        default: return .ambiguous(byName)
        }
    }

    public static func refusal(for query: String, outcome: Outcome, projects: [Repo]) -> String? {
        switch outcome {
        case .found:
            return nil

        case .ambiguous(let matches):
            return "Unified Dev has \(matches.count) projects called '\(query)'. Ask again with one of "
                + "these paths instead: " + listing(matches.map(\.path)) + "."

        case .unknown:
            guard !projects.isEmpty else {
                return "Unified Dev has no projects yet, so there is nowhere to start a workspace. Add "
                    + "an existing git repository with project_add first."
            }
            return "Unified Dev has no project called '\(query)'. It knows "
                + listing(projects.map(\.name))
                + ". Ask again with one of those, or add the repository with project_add first. "
                + "Unified Dev will not start a workspace in a repository it does not know about."
        }
    }

    static func listing(_ items: [String]) -> String {
        let shown = items.prefix(10).map { "'\($0)'" }
        let rest = items.count - shown.count
        var text = shown.count == 1
            ? shown[0]
            : shown.dropLast().joined(separator: ", ") + " and " + shown[shown.count - 1]
        if rest > 0 { text += ", and \(rest) more" }
        return text
    }

    public static func project(atPath path: String, in projects: [Repo]) -> Repo? {
        projects.first { FolderPath.sameFolder($0.path, path) }
    }
}
