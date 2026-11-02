import Testing
import Foundation
@testable import Core

@Suite("One name for a Claude plan")
struct ClaudeAccountPlanTests {
    private let home = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountHome.defaultID(for: .claudeCode),
        directory: URL(filePath: "/nowhere/.claude"),
        isDefault: true
    )

    private func identity(type: String? = nil, tier: String? = nil) -> Data {
        var fields = ["\"emailAddress\":\"ada@example.com\""]
        if let type { fields.append("\"organizationType\":\"\(type)\"") }
        if let tier { fields.append("\"organizationRateLimitTier\":\"\(tier)\"") }
        return Data("{\"oauthAccount\":{\(fields.joined(separator: ","))}}".utf8)
    }

    private func credential(subscription: String? = nil, tier: String? = nil) -> Data {
        var fields: [String] = []
        if let subscription { fields.append("\"subscriptionType\":\"\(subscription)\"") }
        if let tier { fields.append("\"rateLimitTier\":\"\(tier)\"") }
        return Data("{\"claudeAiOauth\":{\(fields.joined(separator: ","))}}".utf8)
    }

    private func identityPlan(_ identity: Data?, _ credential: Data?) -> String? {
        AgentAccountIdentity.read(home, identity: identity, credential: credential).plan
    }

    private func loginMethod(_ identity: Data) -> String? {
        AgentCatalog.claudeDetails(accountJSON: identity, version: nil, apiKeyIsSet: false)
            .first { $0.label == "Login method" }?.value
    }

    @Test("the identity's tier beats a credential that stopped moving")
    func identityBeatsAStaleCredential() {
        let plan = identityPlan(
            identity(type: "claude_max", tier: "default_claude_max_20x"),
            credential(subscription: "max", tier: "default_claude_max_5x")
        )
        #expect(plan == "Ultra")
    }

    @Test("the order holds when the identity is the one saying Max")
    func identityBeatsACredentialSayingUltra() {
        let plan = identityPlan(
            identity(type: "claude_max", tier: "default_claude_max_5x"),
            credential(subscription: "max", tier: "default_claude_max_20x")
        )
        #expect(plan == "Max")
    }

    @Test("the credential answers for a field the identity lacks")
    func credentialFillsWhatTheIdentityLacks() {
        let tierOnly = credential(subscription: "max", tier: "default_claude_max_20x")
        #expect(identityPlan(identity(type: "claude_max"), tierOnly) == "Ultra")
        #expect(identityPlan(identity(), tierOnly) == "Ultra")
        #expect(identityPlan(nil, tierOnly) == "Ultra")
    }

    @Test("an identity with no organisation type still has its tier limited by the credential's type")
    func credentialTypeLimitsTheIdentityTier() {
        let plan = identityPlan(
            identity(tier: "default_claude_max_20x"),
            credential(subscription: "team")
        )
        #expect(plan == "Team")
    }

    @Test(
        "an organisation that is not on Max never reads as Max or Ultra",
        arguments: [
            ("claude_team", "Team"),
            ("claude_enterprise", "Enterprise"),
            ("claude_pro", "Pro"),
        ]
    )
    func otherOrganisationsKeepTheirName(type: String, expected: String) {
        for tier in ["default_claude_max_20x", "default_claude_max_5x"] {
            let plan = identityPlan(
                identity(type: type, tier: tier),
                credential(subscription: "max", tier: tier)
            )
            #expect(plan == expected)
            #expect(loginMethod(identity(type: type, tier: tier)) == "Claude \(expected) account")
        }
    }

    @Test("Settings names a 20x account Ultra and a 5x account Max")
    func settingsFollowsTheTier() {
        #expect(loginMethod(identity(type: "claude_max", tier: "default_claude_max_20x")) == "Claude Ultra account")
        #expect(loginMethod(identity(type: "claude_max", tier: "default_claude_max_5x")) == "Claude Max account")
        #expect(loginMethod(identity(type: "claude_max")) == "Claude Max account")
    }

    @Test("Settings takes a field the identity lacks from the credential, as every other screen does")
    func settingsReadsTheCredential() {
        let details = AgentCatalog.claudeDetails(
            accountJSON: identity(type: "claude_max"),
            credentialJSON: credential(subscription: "max", tier: "default_claude_max_20x"),
            version: nil,
            apiKeyIsSet: false
        )
        #expect(details.first { $0.label == "Login method" }?.value == "Claude Ultra account")
    }

    @Test("an API key still outranks every plan in Settings")
    func apiKeyOutranksThePlan() {
        let details = AgentCatalog.claudeDetails(
            accountJSON: identity(type: "claude_max", tier: "default_claude_max_20x"),
            version: nil,
            apiKeyIsSet: true
        )
        #expect(details.first { $0.label == "Login method" }?.value == AgentCatalog.apiKeyLoginMethod)
    }
}
