import Foundation

public struct PreviewScenario: Sendable, Equatable, Codable {
    public enum RemoteAnswer: String, Sendable, Equatable, Codable {
        case promptly
        case slowly
        case never

        var uploadPack: String? {
            switch self {
            case .promptly: nil
            case .slowly: "sleep 8; git-upload-pack"
            case .never: "false"
            }
        }
    }

    public struct Project: Sendable, Equatable, Codable {
        public var name: String
        public var files: [String: String]
        public var commits: [String]
        public var remoteAhead: [String]
        public var branches: [String]
        public var workspaces: [Workspace]
        public var remote: RemoteAnswer
        public var hidden: Bool

        public init(
            name: String,
            files: [String: String] = [:],
            commits: [String] = [],
            remoteAhead: [String] = [],
            branches: [String] = [],
            workspaces: [Workspace] = [],
            remote: RemoteAnswer = .promptly,
            hidden: Bool = false
        ) {
            self.name = name
            self.files = files
            self.commits = commits
            self.remoteAhead = remoteAhead
            self.branches = branches
            self.workspaces = workspaces
            self.remote = remote
            self.hidden = hidden
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            files = try container.decodeIfPresent([String: String].self, forKey: .files) ?? [:]
            commits = try container.decodeIfPresent([String].self, forKey: .commits) ?? []
            remoteAhead = try container.decodeIfPresent([String].self, forKey: .remoteAhead) ?? []
            branches = try container.decodeIfPresent([String].self, forKey: .branches) ?? []
            workspaces = try container.decodeIfPresent([Workspace].self, forKey: .workspaces) ?? []
            remote = try container.decodeIfPresent(RemoteAnswer.self, forKey: .remote) ?? .promptly
            hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        }
    }

    public struct Workspace: Sendable, Equatable, Codable {
        public var name: String
        public var branch: String
        public var chats: [Chat]
        public var browser: String?
        public var changes: [String: String?]
        public var startedBy: String?

        public init(
            name: String,
            branch: String,
            chats: [Chat] = [],
            browser: String? = nil,
            changes: [String: String?] = [:],
            startedBy: String? = nil
        ) {
            self.name = name
            self.branch = branch
            self.chats = chats
            self.browser = browser
            self.changes = changes
            self.startedBy = startedBy
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            branch = try container.decode(String.self, forKey: .branch)
            chats = try container.decodeIfPresent([Chat].self, forKey: .chats) ?? []
            browser = try container.decodeIfPresent(String.self, forKey: .browser)
            changes = try container.decodeIfPresent([String: String?].self, forKey: .changes) ?? [:]
            startedBy = try container.decodeIfPresent(String.self, forKey: .startedBy)
        }
    }

    public struct Chat: Sendable, Equatable, Codable {
        public var title: String
        public var messages: [Line]
        public var suggestions: [Suggestion]

        public init(title: String, messages: [Line], suggestions: [Suggestion] = []) {
            self.title = title
            self.messages = messages
            self.suggestions = suggestions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            messages = try container.decodeIfPresent([Line].self, forKey: .messages) ?? []
            suggestions = try container.decodeIfPresent([Suggestion].self, forKey: .suggestions) ?? []
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
    public var quotas: [Quota]
    public var looseRepositories: [String]
    public var looseFolders: [String]

    public init(
        welcome: Bool = true,
        projects: [Project],
        quotas: [Quota] = [],
        looseRepositories: [String] = [],
        looseFolders: [String] = []
    ) {
        self.welcome = welcome
        self.projects = projects
        self.quotas = quotas
        self.looseRepositories = looseRepositories
        self.looseFolders = looseFolders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        welcome = try container.decodeIfPresent(Bool.self, forKey: .welcome) ?? true
        projects = try container.decode([Project].self, forKey: .projects)
        quotas = try container.decodeIfPresent([Quota].self, forKey: .quotas) ?? []
        looseRepositories = try container.decodeIfPresent([String].self, forKey: .looseRepositories) ?? []
        looseFolders = try container.decodeIfPresent([String].self, forKey: .looseFolders) ?? []
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
            var startedSoFar: Set<String> = []
            for workspace in project.workspaces {
                defer { startedSoFar.insert(workspace.name) }
                if startedSoFar.contains(workspace.name) {
                    problems.append("workspace \"\(workspace.name)\" is named twice in \"\(name)\"")
                }
                if let starter = workspace.startedBy {
                    if starter == workspace.name {
                        problems.append("workspace \"\(workspace.name)\" in \"\(name)\" is started by itself")
                    } else if !startedSoFar.contains(starter) {
                        problems.append(
                            "workspace \"\(workspace.name)\" in \"\(name)\" is started by \"\(starter)\", "
                                + "which is not a workspace listed before it in the same project"
                        )
                    }
                }
                if workspace.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("a workspace in \"\(name)\" has no name")
                }
                if !Git.isValidBranchName(workspace.branch) || workspace.branch == "main" {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" has an unusable branch \"\(workspace.branch)\"")
                }
                if !branches.insert(workspace.branch).inserted {
                    problems.append("branch \"\(workspace.branch)\" is used twice in \"\(name)\"")
                }
                for path in workspace.changes.keys where !Self.isRelativeFile(path) {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" changes \"\(path)\", which is not a path inside the worktree")
                }
                if let browser = workspace.browser, BrowserAddress.url(from: browser) == nil {
                    problems.append("workspace \"\(workspace.name)\" in \"\(name)\" opens \"\(browser)\", which is not an address")
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
        problems += suggestionProblems
        problems += quotaProblems
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
