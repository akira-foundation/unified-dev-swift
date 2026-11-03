import Testing
import Foundation
@testable import Core

@Suite("Agent account identity")
struct AgentAccountIdentityTests {
    private let claudeHome = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/support/AgentAccounts/claudeCode/work"),
        isDefault: false
    )

    private let codexHome = AgentAccountHome(
        provider: .codex,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/support/AgentAccounts/codex/work"),
        isDefault: false
    )

    private func base64URL(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func codexAuthJSON(email: String, plan: String, expiry: Int = 2_000_000_000) -> Data {
        let claims = #"{"email":"\#(email)","name":"Made Up","exp":\#(expiry),"https://api.openai.com/auth":{"chatgpt_plan_type":"\#(plan)"}}"#
        let token = [base64URL(#"{"alg":"none"}"#), base64URL(claims), "signature"].joined(separator: ".")
        return Data(#"{"auth_mode":"chatgpt","tokens":{"id_token":"\#(token)"}}"#.utf8)
    }

    @Test func claudeIdentityComesFromOauthAccount() {
        let identity = Data(#"{"oauthAccount":{"emailAddress":"a@b.c","displayName":"A","organizationName":"Org","organizationType":"claude_max"}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read.email == "a@b.c")
        #expect(read.displayName == "A")
        #expect(read.organisationName == "Org")
    }

    @Test func aClaudeOrganisationTypeNamesThePlan() {
        let identity = Data(#"{"oauthAccount":{"emailAddress":"a@b.c","organizationType":"claude_enterprise"}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read.email == "a@b.c")
        #expect(read.plan == "Enterprise")
    }

    @Test func aClaudeCredentialAloneNamesThePlan() {
        let credential = Data(#"{"claudeAiOauth":{"subscriptionType":"max","expiresAt":2000000000000}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: credential)
        #expect(read.plan == "Max")
        #expect(read.email == nil)
        #expect(read.expiresAt == Date(timeIntervalSince1970: 2_000_000_000))
    }

    @Test func claudePlanReadsTheTierBesideTheSubscriptionType() {
        func plan(_ tier: String) -> String? {
            let credential = Data(
                "{\"claudeAiOauth\":{\"subscriptionType\":\"max\",\"rateLimitTier\":\"\(tier)\"}}".utf8
            )
            return AgentAccountIdentity.read(claudeHome, identity: nil, credential: credential).plan
        }
        #expect(plan("default_claude_max_20x") == "Ultra")
        #expect(plan("default_claude_max_5x") == "Max")
        #expect(plan("something_new") == "Max")
    }

    @Test func codexIdentityComesFromTheIdTokenClaims() {
        let read = AgentAccountIdentity.read(
            codexHome, identity: nil, credential: codexAuthJSON(email: "a@b.c", plan: "plus")
        )
        #expect(read.email == "a@b.c")
        #expect(read.displayName == "Made Up")
        #expect(read.plan == "Plus")
        #expect(read.expiresAt == Date(timeIntervalSince1970: 2_000_000_000))
    }

    @Test func codexReadsTheSameFileWhicheverParameterCarriesIt() {
        let file = codexAuthJSON(email: "a@b.c", plan: "pro")
        let read = AgentAccountIdentity.read(codexHome, identity: file, credential: file)
        #expect(read.email == "a@b.c")
        #expect(read.plan == "Pro 20x")
    }

    @Test func codexWithOnlyAnApiKeyCarriesNothingOfIt() {
        let file = Data(#"{"auth_mode":"apikey","OPENAI_API_KEY":"made-up-key"}"#.utf8)
        let read = AgentAccountIdentity.read(codexHome, identity: nil, credential: file)
        #expect(read == AgentAccountIdentity())
        #expect(!String(describing: read).contains("made-up-key"))
    }

    @Test func aMalformedIdTokenCarriesNothing() {
        let file = Data(#"{"tokens":{"id_token":"not-a-token"}}"#.utf8)
        let read = AgentAccountIdentity.read(codexHome, identity: nil, credential: file)
        #expect(read == AgentAccountIdentity())
    }

    @Test func aNullOauthAccountCarriesNothing() {
        let identity = Data(#"{"oauthAccount":null}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read == AgentAccountIdentity())
    }

    @Test func aNullClaudeAiOauthCarriesNothing() {
        let credential = Data(#"{"claudeAiOauth":null}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: credential)
        #expect(read == AgentAccountIdentity())
    }

    @Test func anEmptyOauthAccountCarriesNothing() {
        let identity = Data(#"{"oauthAccount":{}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read == AgentAccountIdentity())
    }

    @Test func anEmptyClaudeAiOauthCarriesNothing() {
        let credential = Data(#"{"claudeAiOauth":{}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: credential)
        #expect(read == AgentAccountIdentity())
    }

    @Test func anOauthAccountOfOnlyNullMembersCarriesNothing() {
        let identity = Data(#"{"oauthAccount":{"emailAddress":null}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read == AgentAccountIdentity())
    }

    @Test func aClaudeAiOauthOfOnlyNullMembersCarriesNothing() {
        let credential = Data(#"{"claudeAiOauth":{"subscriptionType":null}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: credential)
        #expect(read == AgentAccountIdentity())
    }

    @Test func aNonObjectOauthAccountCarriesNothing() {
        let identity = Data(#"{"oauthAccount":"signed-in"}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read == AgentAccountIdentity())
    }

    @Test func nullCodexTokensAndApiKeyCarryNothing() {
        let file = Data(#"{"tokens":null,"OPENAI_API_KEY":null}"#.utf8)
        let read = AgentAccountIdentity.read(codexHome, identity: nil, credential: file)
        #expect(read == AgentAccountIdentity())
    }

    @Test func anEmptyDirectoryReadsAsAnEmptyIdentityAndNotAsAnError() {
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: nil)
        #expect(read == AgentAccountIdentity())
    }

    @Test func anUnparseableIdentityFileCarriesNothing() {
        let read = AgentAccountIdentity.read(claudeHome, identity: Data("not json".utf8), credential: nil)
        #expect(read == AgentAccountIdentity())
    }

    @Test func anOauthAccountWithoutAnyCredentialGivesTheEmailAndClaimsNothingElse() {
        let identity = Data(
            #"{"oauthAccount":{"accountUuid":"u-1","emailAddress":"a@b.c","organizationUuid":"o-1"}}"#.utf8
        )
        let read = AgentAccountIdentity.read(claudeHome, identity: identity, credential: nil)
        #expect(read.email == "a@b.c")
        #expect(read.displayName == nil)
        #expect(read.organisationName == nil)
        #expect(read.plan == nil)
        #expect(read.expiresAt == nil)
    }

    @Test func theIdentityHasNoMemberThatCouldClaimASession() {
        let labels = Mirror(reflecting: AgentAccountIdentity()).children.compactMap(\.label)
        #expect(labels == ["email", "displayName", "organisationName", "plan", "expiresAt"])
    }
}
