import Foundation

public struct AgentAccountIdentity: Sendable, Hashable {
    public enum Method: Sendable, Hashable {
        case subscription
        case apiKey
        case none
    }

    public var email: String?
    public var displayName: String?
    public var organisationName: String?
    public var plan: String?
    public var expiresAt: Date?
    public var authMethod: Method

    public init(
        email: String? = nil,
        displayName: String? = nil,
        organisationName: String? = nil,
        plan: String? = nil,
        expiresAt: Date? = nil,
        authMethod: Method = .none
    ) {
        self.email = email
        self.displayName = displayName
        self.organisationName = organisationName
        self.plan = plan
        self.expiresAt = expiresAt
        self.authMethod = authMethod
    }

    public static func read(_ home: AgentAccountHome, identity: Data?, credential: Data?) -> AgentAccountIdentity {
        switch home.provider {
        case .claudeCode: readClaude(identity: identity, credential: credential)
        case .codex: readCodex(credential: credential)
        case .grok, .cursor, .openCode: AgentAccountIdentity()
        }
    }

    private static func readClaude(identity: Data?, credential: Data?) -> AgentAccountIdentity {
        let account = identity.flatMap(JSONValue.parse)?["oauthAccount"].flatMap(populatedObject)
        let oauth = credential.flatMap(JSONValue.parse)?["claudeAiOauth"].flatMap(populatedObject)
        guard account != nil || oauth != nil else { return AgentAccountIdentity() }

        return AgentAccountIdentity(
            email: account?["emailAddress"]?.stringValue.flatMap(nonEmpty),
            displayName: account?["displayName"]?.stringValue.flatMap(nonEmpty),
            organisationName: account?["organizationName"]?.stringValue.flatMap(nonEmpty),
            plan: oauth?["subscriptionType"]?.stringValue.flatMap(AgentAccountReader.claudePlan),
            expiresAt: oauth?["expiresAt"]?.doubleValue.map { Date(timeIntervalSince1970: $0 / 1000) },
            authMethod: .subscription
        )
    }

    private static func readCodex(credential: Data?) -> AgentAccountIdentity {
        guard let file = credential.flatMap(JSONValue.parse) else { return AgentAccountIdentity() }
        let claims = file["tokens"]?["id_token"]?.stringValue.flatMap(AgentCatalog.decodeCodexIDToken)
        if let claims {
            return AgentAccountIdentity(
                email: claims.email,
                displayName: claims.name,
                plan: claims.planType.flatMap(AgentAccountReader.codexPlan),
                expiresAt: claims.expiresAt,
                authMethod: .subscription
            )
        }
        let apiKeyIsSet = file["OPENAI_API_KEY"]?.stringValue.flatMap(nonEmpty) != nil
        return AgentAccountIdentity(authMethod: apiKeyIsSet ? .apiKey : .none)
    }

    private static func populatedObject(_ value: JSONValue) -> JSONValue? {
        guard let object = value.objectValue, object.values.contains(where: { !$0.isNull }) else { return nil }
        return value
    }

    private static func nonEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
