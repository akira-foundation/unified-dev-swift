import Foundation

extension PreviewScenario {
    public struct Account: Sendable, Equatable, Codable {
        public var provider: AgentKind
        public var email: String
        public var displayName: String?
        public var organisation: String?
        public var plan: String?
        public var rateLimitTier: String?
        public var label: String?
        public var missing: Bool

        public var id: AgentAccountID {
            guard let label else { return AgentAccountHome.defaultID(for: provider) }
            return AgentAccountID("preview.\(provider.rawValue).\(label.lowercased())")
        }

        public init(
            provider: AgentKind = .claudeCode,
            email: String,
            displayName: String? = nil,
            organisation: String? = nil,
            plan: String? = nil,
            rateLimitTier: String? = nil,
            label: String? = nil,
            missing: Bool = false
        ) {
            self.provider = provider
            self.email = email
            self.displayName = displayName
            self.organisation = organisation
            self.plan = plan
            self.rateLimitTier = rateLimitTier
            self.label = label
            self.missing = missing
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            provider = try container.decodeIfPresent(AgentKind.self, forKey: .provider) ?? .claudeCode
            email = try container.decode(String.self, forKey: .email)
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            organisation = try container.decodeIfPresent(String.self, forKey: .organisation)
            plan = try container.decodeIfPresent(String.self, forKey: .plan)
            rateLimitTier = try container.decodeIfPresent(String.self, forKey: .rateLimitTier)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            missing = try container.decodeIfPresent(Bool.self, forKey: .missing) ?? false
        }

        public var problems: [String] {
            var found: [String] = []
            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                found.append("an account has no email to be named by")
            }
            if provider != .claudeCode, provider != .codex {
                found.append("\(provider.label) keeps no identity on disk, so it has no account to seed")
            }
            if let label, !PreviewScenario.isFolderName(label) {
                found.append("account \"\(label)\" is not a plain folder name")
            }
            if label == nil, missing {
                found.append("a default account cannot be missing, because the app always has one")
            }
            return found
        }
    }
}
