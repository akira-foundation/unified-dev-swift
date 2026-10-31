import Foundation

extension PreviewScenario {
    public struct Account: Sendable, Equatable, Codable {
        public var provider: AgentKind
        public var email: String
        public var displayName: String?
        public var organisation: String?
        public var plan: String?

        public init(
            provider: AgentKind = .claudeCode,
            email: String,
            displayName: String? = nil,
            organisation: String? = nil,
            plan: String? = nil
        ) {
            self.provider = provider
            self.email = email
            self.displayName = displayName
            self.organisation = organisation
            self.plan = plan
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            provider = try container.decodeIfPresent(AgentKind.self, forKey: .provider) ?? .claudeCode
            email = try container.decode(String.self, forKey: .email)
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            organisation = try container.decodeIfPresent(String.self, forKey: .organisation)
            plan = try container.decodeIfPresent(String.self, forKey: .plan)
        }

        public var problems: [String] {
            var found: [String] = []
            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                found.append("an account has no email to be named by")
            }
            if provider != .claudeCode, provider != .codex {
                found.append("\(provider.label) keeps no identity on disk, so it has no account to seed")
            }
            return found
        }
    }
}
