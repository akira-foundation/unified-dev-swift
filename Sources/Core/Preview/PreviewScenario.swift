import Foundation

public struct PreviewScenario: Sendable, Equatable, Codable {
    public struct Project: Sendable, Equatable, Codable {
        public var name: String
        public var files: [String: String]
        public var commits: [String]
        public var remoteAhead: [String]
        public var branches: [String]
        public var workspaces: [Workspace]

        public init(
            name: String,
            files: [String: String] = [:],
            commits: [String] = [],
            remoteAhead: [String] = [],
            branches: [String] = [],
            workspaces: [Workspace] = []
        ) {
            self.name = name
            self.files = files
            self.commits = commits
            self.remoteAhead = remoteAhead
            self.branches = branches
            self.workspaces = workspaces
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            files = try container.decodeIfPresent([String: String].self, forKey: .files) ?? [:]
            commits = try container.decodeIfPresent([String].self, forKey: .commits) ?? []
            remoteAhead = try container.decodeIfPresent([String].self, forKey: .remoteAhead) ?? []
            branches = try container.decodeIfPresent([String].self, forKey: .branches) ?? []
            workspaces = try container.decodeIfPresent([Workspace].self, forKey: .workspaces) ?? []
        }
    }

    public struct Workspace: Sendable, Equatable, Codable {
        public var name: String
        public var branch: String
        public var chats: [Chat]

        public init(name: String, branch: String, chats: [Chat] = []) {
            self.name = name
            self.branch = branch
            self.chats = chats
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            branch = try container.decode(String.self, forKey: .branch)
            chats = try container.decodeIfPresent([Chat].self, forKey: .chats) ?? []
        }
    }

    public struct Chat: Sendable, Equatable, Codable {
        public var title: String
        public var messages: [Line]

        public init(title: String, messages: [Line]) {
            self.title = title
            self.messages = messages
        }
    }

    public struct Line: Sendable, Equatable, Codable {
        public enum Speaker: String, Sendable, Codable {
            case user
            case agent
        }

        public var from: Speaker
        public var text: String

        public init(from: Speaker, text: String) {
            self.from = from
            self.text = text
        }
    }

    public var welcome: Bool
    public var projects: [Project]

    public init(welcome: Bool = true, projects: [Project]) {
        self.welcome = welcome
        self.projects = projects
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        welcome = try container.decodeIfPresent(Bool.self, forKey: .welcome) ?? true
        projects = try container.decode([Project].self, forKey: .projects)
    }

    public static func read(_ data: Data) throws -> PreviewScenario {
        let scenario: PreviewScenario
        do {
            scenario = try JSONDecoder().decode(PreviewScenario.self, from: data)
        } catch {
            throw PreviewScenarioError.unreadable(String(describing: error))
        }
        let problems = scenario.problems
        guard problems.isEmpty else { throw PreviewScenarioError.invalid(problems) }
        return scenario
    }

    public static func read(path: String) throws -> PreviewScenario {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw PreviewScenarioError.unreadable("nothing could be read at \(path)")
        }
        return try read(data)
    }

    public var problems: [String] {
        var problems: [String] = []
        if projects.isEmpty { problems.append("the scenario names no projects") }
        var seen = Set<String>()
        for project in projects {
            let name = project.name
            if !Self.isFolderName(name) {
                problems.append("project \"\(name)\" is not a plain folder name")
            }
            if !seen.insert(name.lowercased()).inserted {
                problems.append("project \"\(name)\" is named twice")
            }
            for path in project.files.keys where !Self.isRelativeFile(path) {
                problems.append("project \"\(name)\" writes \"\(path)\", which is not a path inside the project")
            }
            var branches = Set<String>()
            for workspace in project.workspaces {
                if workspace.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("a workspace in \"\(name)\" has no name")
                }
                if !Git.isValidBranchName(workspace.branch) || workspace.branch == "main" {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" has an unusable branch \"\(workspace.branch)\"")
                }
                if !branches.insert(workspace.branch).inserted {
                    problems.append("branch \"\(workspace.branch)\" is used twice in \"\(name)\"")
                }
            }
            for branch in project.branches {
                if !Git.isValidBranchName(branch) || branch == "main" {
                    problems.append("branch \"\(branch)\" in \"\(name)\" is unusable")
                }
                if !branches.insert(branch).inserted {
                    problems.append("branch \"\(branch)\" is used twice in \"\(name)\"")
                }
            }
            for branch in branches.sorted() where branches.contains(where: { branch.hasPrefix($0 + "/") }) {
                problems.append("branch \"\(branch)\" in \"\(name)\" sits under another branch of the scenario, which git cannot hold")
            }
        }
        return problems
    }

    static func isFolderName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 64, !name.hasPrefix(".") else { return false }
        return name.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_" || $0 == "."
        }
    }

    static func isRelativeFile(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && $0.lowercased() != ".git" }
    }
}

public enum PreviewScenarioError: Error, CustomStringConvertible, Equatable {
    case unreadable(String)
    case invalid([String])
    case notAPreview
    case alreadySeeded

    public var description: String {
        switch self {
        case .unreadable(let reason): "The scenario could not be read: \(reason)"
        case .invalid(let problems): "The scenario is not usable: " + problems.joined(separator: "; ")
        case .notAPreview:
            "Only a worktree preview seeds a scenario. This copy has no preview identity, so nothing was created."
        case .alreadySeeded: "This preview already holds projects, so the scenario was not applied again."
        }
    }
}
