import Foundation

extension PreviewScenario {
    public struct Suggestion: Sendable, Equatable, Codable {
        public enum Seeded: String, Sendable, Codable {
            case pending
            case started
            case dismissed
            case withdrawn
        }

        public var title: String
        public var why: String
        public var prompt: String
        public var project: String?
        public var looseRepository: String?
        public var looseFolder: String?
        public var state: Seeded
        public var startedIn: String?

        public init(
            title: String,
            why: String,
            prompt: String,
            project: String? = nil,
            looseRepository: String? = nil,
            looseFolder: String? = nil,
            state: Seeded = .pending,
            startedIn: String? = nil
        ) {
            self.title = title
            self.why = why
            self.prompt = prompt
            self.project = project
            self.looseRepository = looseRepository
            self.looseFolder = looseFolder
            self.state = state
            self.startedIn = startedIn
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            why = try container.decode(String.self, forKey: .why)
            prompt = try container.decode(String.self, forKey: .prompt)
            project = try container.decodeIfPresent(String.self, forKey: .project)
            looseRepository = try container.decodeIfPresent(String.self, forKey: .looseRepository)
            looseFolder = try container.decodeIfPresent(String.self, forKey: .looseFolder)
            state = try container.decodeIfPresent(Seeded.self, forKey: .state) ?? .pending
            startedIn = try container.decodeIfPresent(String.self, forKey: .startedIn)
        }
    }

    var suggestionProblems: [String] {
        var problems = looseProblems
        let projectNames = Set(projects.map { $0.name.lowercased() })
        for project in projects {
            let workspaceNames = Set(project.workspaces.map(\.name))
            for workspace in project.workspaces {
                var waiting = 0
                for chat in workspace.chats {
                    for suggestion in chat.suggestions {
                        problems += problemsOf(suggestion, in: chat, projects: projectNames, workspaces: workspaceNames)
                        if suggestion.state == .pending { waiting += 1 }
                    }
                }
                if waiting > WorkSuggestion.undecidedLimit {
                    problems.append(
                        "workspace \"\(workspace.name)\" holds more than \(WorkSuggestion.undecidedLimit) suggestions waiting"
                    )
                }
            }
        }
        return problems
    }

    private var looseProblems: [String] {
        var problems: [String] = []
        var seen = Set<String>()
        for name in looseRepositories + looseFolders {
            if !Self.isFolderName(name) { problems.append("loose folder \"\(name)\" is not a plain folder name") }
            if !seen.insert(name.lowercased()).inserted { problems.append("loose folder \"\(name)\" is named twice") }
            if projects.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                problems.append("loose folder \"\(name)\" has the name of a project")
            }
        }
        return problems
    }

    private func problemsOf(
        _ suggestion: Suggestion, in chat: Chat, projects: Set<String>, workspaces: Set<String>
    ) -> [String] {
        var problems: [String] = []
        let label = "suggestion \"\(suggestion.title)\" in \"\(chat.title)\""
        let blank = [suggestion.title, suggestion.why, suggestion.prompt]
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if blank { problems.append("\(label) is missing its title, its reason or its prompt") }
        let places = [suggestion.project, suggestion.looseRepository, suggestion.looseFolder].compactMap(\.self)
        if places.count > 1 {
            problems.append("\(label) names both a project and a loose repository or folder")
        }
        if let named = suggestion.looseRepository, !looseRepositories.contains(named) {
            problems.append("\(label) names a loose repository the scenario does not make")
        }
        if let named = suggestion.looseFolder, !looseFolders.contains(named) {
            problems.append("\(label) names a loose folder the scenario does not make")
        }
        if let named = suggestion.project, !projects.contains(named.lowercased()),
           WorkSuggestionTarget.remoteSlug(named) == nil {
            problems.append("\(label) names \"\(named)\", which is neither a project of the scenario nor owner/repository")
        }
        if (suggestion.state == .started) != (suggestion.startedIn != nil) {
            problems.append("\(label) must name the workspace it started in when, and only when, it is started")
        }
        if let started = suggestion.startedIn, !workspaces.contains(started) {
            problems.append("\(label) started in \"\(started)\", which is not a workspace of its project")
        }
        return problems
    }
}
