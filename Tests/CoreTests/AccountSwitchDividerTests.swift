import Testing
import Foundation
@testable import Core

@Suite("Naming the account in the divider of an account switch", .tags(.persistence), .scratchDirectory)
struct AccountSwitchDividerTests {
    private let work = AgentAccountRow(
        id: AgentAccountID("work"), provider: .claudeCode, directory: "/accounts/claudeCode/work", label: "Work"
    )

    @Test func aSwitchBetweenAccountsOfOneProviderNamesTheAccount() {
        let mark = HandoffMark.continued(agent: .claudeCode, model: "opus", from: .claudeCode, account: "ada@client.example")

        #expect(mark.sentence == "Continued with Claude Code under ada@client.example · opus")
    }

    @Test func aSwitchOfProviderDoesNotNameTheAccount() {
        let mark = HandoffMark.continued(agent: .codex, model: "gpt-5", from: .claudeCode, account: "ada@client.example")

        #expect(mark.sentence == "Continued with Codex · gpt-5")
    }

    @Test func aSwitchWithNoAccountNameReadsAsBefore() {
        #expect(HandoffMark.continued(agent: .claudeCode, model: "opus", from: .claudeCode).sentence
            == "Continued with Claude Code · opus")
        #expect(HandoffMark.continued(agent: .claudeCode, model: "opus", from: .claudeCode, account: "").sentence
            == "Continued with Claude Code · opus")
    }

    @Test func aDividerStoredBeforeAccountsWereNamedStillRendersAsItDid() throws {
        let stored = Data(#"{"continued":{"agent":"claudeCode","model":"opus","from":"claudeCode"}}"#.utf8)
        let mark = try #require(HandoffMark.decode(stored))

        #expect(mark == .continued(agent: .claudeCode, model: "opus", from: .claudeCode))
        #expect(mark.sentence == "Continued with Claude Code · opus")
    }

    @Test func theNameSurvivesEncoding() throws {
        let mark = HandoffMark.continued(agent: .claudeCode, model: "opus", from: .claudeCode, account: "Work")

        #expect(HandoffMark.decode(mark.payload) == mark)
    }

    @Test func theAccountIsSpokenAsTheOwnerKnowsIt() {
        let work = AccountFixture.work
        let standings = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(work, email: "ada@client.example"),
        ]

        #expect(AgentAccountNames.spoken(of: work, among: standings) == "ada@client.example")
        #expect(AgentAccountNames.spoken(of: AccountFixture.defaultClaude, among: standings) == "the default account")
        #expect(AgentAccountNames.spoken(of: AccountFixture.personal, among: standings) == "personal")
    }

    @Test func theStoreWritesTheNameIntoTheDivider() async throws {
        let store = try makeTestStore("divider-account")
        try await store.add(work)
        let session = try await store.upsert(Session(workspaceID: nil, agentSessionID: "c1"))
        let target = SessionSegmentTarget(agentKind: .claudeCode, accountID: work.id, model: "opus", effort: "")

        _ = try await store.switchSegment(sessionID: session.id, to: target.named("Work"))

        let divider = try #require(try await store.messages(sessionID: session.id).last { $0.kind == .handoff })
        #expect(HandoffMark.decode(divider.payload)?.sentence == "Continued with Claude Code under Work · opus")
    }
}
