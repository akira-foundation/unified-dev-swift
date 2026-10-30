import Foundation

extension PreviewScenario {
    public static let agentSettingsKey = "preview.agentSettings"

    public struct AgentSettings: Sendable, Equatable, Codable {
        public struct Agent: Sendable, Equatable, Codable {
            public var agent: AgentKind
            public var state: AgentStatus.Connection
            public var version: String?
            public var details: [AgentDetail]

            public init(
                agent: AgentKind,
                state: AgentStatus.Connection,
                version: String? = nil,
                details: [AgentDetail] = []
            ) {
                self.agent = agent
                self.state = state
                self.version = version
                self.details = details
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                agent = try container.decode(AgentKind.self, forKey: .agent)
                state = try container.decode(AgentStatus.Connection.self, forKey: .state)
                version = try container.decodeIfPresent(String.self, forKey: .version)
                details = try container.decodeIfPresent([AgentDetail].self, forKey: .details) ?? []
            }

            var status: AgentStatus {
                AgentStatus(kind: agent, connection: state, version: version, details: details)
            }
        }

        public var agents: [Agent]
        public var github: String?

        public init(agents: [Agent] = [], github: String? = nil) {
            self.agents = agents
            self.github = github
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            agents = try container.decodeIfPresent([Agent].self, forKey: .agents) ?? []
            github = try container.decodeIfPresent(String.self, forKey: .github)
        }

        public var statuses: [AgentStatus] {
            AgentKind.allCases.map { kind in
                agents.first { $0.agent == kind }?.status ?? AgentStatus(kind: kind, connection: .notInstalled)
            }
        }

        public func stored() -> Data? {
            try? JSONEncoder().encode(self)
        }

        public static func stored(_ data: Data?) -> AgentSettings? {
            data.flatMap { try? JSONDecoder().decode(AgentSettings.self, from: $0) }
        }

        public static func seeded(in defaults: UserDefaults = .standard) -> AgentSettings? {
            stored(defaults.data(forKey: agentSettingsKey))
        }

        public static func adopt(_ settings: AgentSettings?, in defaults: UserDefaults = .standard) {
            guard let settings else { return defaults.removeObject(forKey: agentSettingsKey) }
            defaults.set(settings.stored(), forKey: agentSettingsKey)
            GitHubIdentity.adopt(settings.github)
        }
    }

    var agentSettingsProblems: [String] {
        guard let agentSettings else { return [] }
        var problems: [String] = []
        var seen = Set<AgentKind>()
        for agent in agentSettings.agents {
            let name = agent.agent.rawValue
            if !seen.insert(agent.agent).inserted {
                problems.append("agent settings for \(name) are named twice")
            }
            if agent.state == .notInstalled, agent.version != nil || !agent.details.isEmpty {
                problems.append("agent \(name) is not installed, so it has no version or account to show")
            }
            var labels = Set<String>()
            for detail in agent.details {
                guard !detail.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    problems.append("a detail of agent \(name) has no label")
                    continue
                }
                if !labels.insert(detail.label).inserted {
                    problems.append("detail \"\(detail.label)\" of agent \(name) is named twice")
                }
            }
        }
        if let github = agentSettings.github, github.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("the GitHub account in agent settings is blank; leave it out to show none")
        }
        return problems
    }
}
