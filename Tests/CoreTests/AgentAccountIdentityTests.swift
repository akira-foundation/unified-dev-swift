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
        #expect(read.plan == "Max")
        #expect(read.authMethod == .subscription)
    }

    @Test func claudePlanFallsBackToTheCredentialWhenIdentityIsMissing() {
        let credential = Data(#"{"claudeAiOauth":{"subscriptionType":"max","expiresAt":2000000000000}}"#.utf8)
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: credential)
        #expect(read.plan == "Max")
        #expect(read.email == nil)
        #expect(read.expiresAt == Date(timeIntervalSince1970: 2_000_000_000))
        #expect(read.authMethod == .subscription)
    }

    @Test func codexIdentityComesFromTheIdTokenClaims() {
        let read = AgentAccountIdentity.read(
            codexHome, identity: nil, credential: codexAuthJSON(email: "a@b.c", plan: "plus")
        )
        #expect(read.email == "a@b.c")
        #expect(read.displayName == "Made Up")
        #expect(read.plan == "Plus")
        #expect(read.expiresAt == Date(timeIntervalSince1970: 2_000_000_000))
        #expect(read.authMethod == .subscription)
    }

    @Test func codexReadsTheSameFileWhicheverParameterCarriesIt() {
        let file = codexAuthJSON(email: "a@b.c", plan: "pro")
        let read = AgentAccountIdentity.read(codexHome, identity: file, credential: file)
        #expect(read.email == "a@b.c")
        #expect(read.plan == "Pro 20x")
    }

    @Test func codexWithOnlyAnApiKeyReadsAsApiKey() {
        let file = Data(#"{"auth_mode":"apikey","OPENAI_API_KEY":"made-up-key"}"#.utf8)
        let read = AgentAccountIdentity.read(codexHome, identity: nil, credential: file)
        #expect(read.authMethod == .apiKey)
        #expect(read.email == nil)
    }

    @Test func aMalformedIdTokenReadsAsNoSession() {
        let file = Data(#"{"tokens":{"id_token":"not-a-token"}}"#.utf8)
        let read = AgentAccountIdentity.read(codexHome, identity: nil, credential: file)
        #expect(read.authMethod == .none)
        #expect(read.email == nil)
    }

    @Test func anEmptyDirectoryReadsAsNoSessionAndNotAsAnError() {
        let read = AgentAccountIdentity.read(claudeHome, identity: nil, credential: nil)
        #expect(read.authMethod == .none)
        #expect(read.email == nil)
        #expect(read.plan == nil)
    }

    @Test func anUnparseableIdentityFileReadsAsNoSessionAndCarriesNothingFromIt() {
        let read = AgentAccountIdentity.read(claudeHome, identity: Data("not json".utf8), credential: nil)
        #expect(read.authMethod == .none)
        #expect(read.email == nil)
    }
}
