import Foundation

public enum ProjectHideTrouble: Sendable, Equatable {
    case noProjectNamed(tool: String)
    case nothingRegistered(tool: String)
    case unknown(query: String, known: [String])
    case ambiguous(query: String, paths: [String])
    case unexplained(tool: String, message: String)

    public var sentence: String {
        switch self {
        case .noProjectNamed(let tool):
            return """
                \(tool) needs the project to act on, named by the name Unified Dev shows in its \
                sidebar, by the absolute path of the repository, or by the id project_list \
                prints. Call project_list to see them.
                """

        case .nothingRegistered(let tool):
            return """
                Unified Dev has no projects, so \(tool) has nothing to act on. Retrying will not change \
                that. Register an existing git repository with project_add first.
                """

        case let .unknown(query, known):
            return """
                Unified Dev has no project called '\(query)', so there is nothing to hide or show under \
                that name. It knows \(BridgeProjectLookup.listing(known)). Retrying with the same \
                name will fail the same way: ask again with one of those, with the repository's \
                absolute path, or with an id from project_list.
                """

        case let .ambiguous(query, paths):
            return """
                Unified Dev has \(paths.count) projects called '\(query)' and will not guess which one \
                you meant. Ask again with one of these paths instead: \
                \(BridgeProjectLookup.listing(paths)).
                """

        case let .unexplained(tool, message):
            return "Unified Dev could not \(tool == "project_hide" ? "hide" : "show") that project: \(message)"
        }
    }

    public static func diagnose(
        query: String,
        outcome: BridgeProjectLookup.Outcome,
        projects: [Repo],
        tool: String
    ) -> ProjectHideTrouble? {
        switch outcome {
        case .found:
            return nil
        case .ambiguous(let matches):
            return .ambiguous(query: query, paths: matches.map(\.path))
        case .unknown:
            guard !projects.isEmpty else { return .nothingRegistered(tool: tool) }
            return .unknown(query: query, known: projects.map(\.name))
        }
    }
}
