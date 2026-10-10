import Foundation

public struct PreviewScenario: Sendable, Equatable, Codable {
    public enum RemoteAnswer: String, Sendable, Equatable, Codable {
        case promptly
        case slowly
        case never
        case absent

        public var exists: Bool { self != .absent }

        var uploadPack: String? {
            switch self {
            case .promptly, .absent: nil
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
        public var commits: [String]
        public var startedBy: String?
        public var unread: Bool
        public var spareFiles: Int

        public static let spareFileCeiling = 4_000

        public init(
            name: String,
            branch: String,
            chats: [Chat] = [],
            browser: String? = nil,
            changes: [String: String?] = [:],
            commits: [String] = [],
            startedBy: String? = nil,
            unread: Bool = false,
            spareFiles: Int = 0
        ) {
            self.name = name
            self.branch = branch
            self.chats = chats
            self.browser = browser
            self.changes = changes
            self.commits = commits
            self.startedBy = startedBy
            self.unread = unread
            self.spareFiles = spareFiles
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            branch = try container.decode(String.self, forKey: .branch)
            chats = try container.decodeIfPresent([Chat].self, forKey: .chats) ?? []
            browser = try container.decodeIfPresent(String.self, forKey: .browser)
            changes = try container.decodeIfPresent([String: String?].self, forKey: .changes) ?? [:]
            commits = try container.decodeIfPresent([String].self, forKey: .commits) ?? []
            startedBy = try container.decodeIfPresent(String.self, forKey: .startedBy)
            unread = try container.decodeIfPresent(Bool.self, forKey: .unread) ?? false
            spareFiles = try container.decodeIfPresent(Int.self, forKey: .spareFiles) ?? 0
        }

        public static func spareFileNames(_ count: Int) -> [String] {
            guard count > 0 else { return [] }
            return (1...count).map { "spare/note-\($0).txt" }
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
        public var question: Question?

        public init(from: Speaker, text: String = "", question: Question? = nil) {
            self.from = from
            self.text = text
            self.question = question
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            from = try container.decode(Speaker.self, forKey: .from)
            question = try container.decodeIfPresent(Question.self, forKey: .question)
            text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        }
    }

    public var welcome: Bool
    public var projects: [Project]
    public var quotas: [Quota]
    public var looseRepositories: [String]
    public var looseFolders: [String]
    public var recentFolders: [String]
    public var silentAgents: [AgentKind]
    public var agentsWithoutLimits: [AgentKind]

    public init(
        welcome: Bool = true,
        projects: [Project],
        quotas: [Quota] = [],
        looseRepositories: [String] = [],
        looseFolders: [String] = [],
        recentFolders: [String] = [],
        silentAgents: [AgentKind] = [],
        agentsWithoutLimits: [AgentKind] = []
    ) {
        self.welcome = welcome
        self.projects = projects
        self.quotas = quotas
        self.looseRepositories = looseRepositories
        self.looseFolders = looseFolders
        self.recentFolders = recentFolders
        self.silentAgents = silentAgents
        self.agentsWithoutLimits = agentsWithoutLimits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        welcome = try container.decodeIfPresent(Bool.self, forKey: .welcome) ?? true
        projects = try container.decode([Project].self, forKey: .projects)
        quotas = try container.decodeIfPresent([Quota].self, forKey: .quotas) ?? []
        looseRepositories = try container.decodeIfPresent([String].self, forKey: .looseRepositories) ?? []
        looseFolders = try container.decodeIfPresent([String].self, forKey: .looseFolders) ?? []
        recentFolders = try container.decodeIfPresent([String].self, forKey: .recentFolders) ?? []
        silentAgents = try container.decodeIfPresent([AgentKind].self, forKey: .silentAgents) ?? []
        agentsWithoutLimits = try container.decodeIfPresent([AgentKind].self, forKey: .agentsWithoutLimits) ?? []
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
