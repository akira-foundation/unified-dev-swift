import Foundation

extension PreviewScenario {
    public struct Transcript: Sendable, Equatable, Codable {
        public var provider: AgentKind
        public var project: String?
        public var model: String
        public var daysAgo: Int
        public var turns: Int
        public var padding: Int
        public var truncated: Bool

        public init(
            provider: AgentKind = .claudeCode,
            project: String? = nil,
            model: String = "claude-opus-5",
            daysAgo: Int = 0,
            turns: Int = 20,
            padding: Int = 0,
            truncated: Bool = false
        ) {
            self.provider = provider
            self.project = project
            self.model = model
            self.daysAgo = daysAgo
            self.turns = turns
            self.padding = padding
            self.truncated = truncated
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            provider = try container.decodeIfPresent(AgentKind.self, forKey: .provider) ?? .claudeCode
            project = try container.decodeIfPresent(String.self, forKey: .project)
            model = try container.decodeIfPresent(String.self, forKey: .model) ?? "claude-opus-5"
            daysAgo = try container.decodeIfPresent(Int.self, forKey: .daysAgo) ?? 0
            turns = try container.decodeIfPresent(Int.self, forKey: .turns) ?? 20
            padding = try container.decodeIfPresent(Int.self, forKey: .padding) ?? 0
            truncated = try container.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
        }

        public static let turnCeiling = 5_000
        public static let paddingCeiling = 4_000

        public var problems: [String] {
            var found: [String] = []
            if turns < 1 || turns > Self.turnCeiling {
                found.append("a transcript needs between 1 and \(Self.turnCeiling) turns, not \(turns)")
            }
            if padding < 0 || padding > Self.paddingCeiling {
                found.append("transcript padding is capped at \(Self.paddingCeiling) characters")
            }
            if daysAgo < 0 || daysAgo > 60 {
                found.append("a transcript can be dated up to 60 days back, not \(daysAgo)")
            }
            return found
        }
    }
}
