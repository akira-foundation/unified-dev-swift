import Testing
import Foundation
@testable import Core

@Suite("The account section of the composer's settings")
struct ComposerAccountSectionTests {
    private let repo = RepoID("billing")

    private var two: [AgentAccountStanding] {
        [
            AccountFixture.standing(AccountFixture.defaultClaude, email: "me@home.com"),
            AccountFixture.standing(AccountFixture.work, email: "me@client.com"),
            AccountFixture.standing(AccountFixture.defaultCodex),
        ]
    }

    private func section(
        repoID: RepoID?,
        project: AgentAccountID? = nil,
        provider: AgentKind = .claudeCode,
        standings: [AgentAccountStanding]? = nil
    ) -> ComposerAccountSection? {
        let all = standings ?? two
        let choice = AgentAccountChoice.resolve(provider: provider, project: project, standings: all)
        return ComposerAccountSection.make(repoID: repoID, provider: provider, choice: choice, standings: all)
    }

    @Test func twoAccountsForTheChatsAgentShowTheOneInUse() throws {
        let made = try #require(section(repoID: repo, project: AccountFixture.work.id))
        #expect(made.title == "me@client.com")
        #expect(made.sentence == "me@client.com runs here, chosen for the project.")
        #expect(!made.warns)
        #expect(made.repoID == repo)
    }

    @Test func oneAccountForTheChatsAgentIsNothingToDecide() {
        #expect(section(repoID: repo, provider: .codex) == nil)
        #expect(section(repoID: repo, standings: [AccountFixture.standing(AccountFixture.defaultClaude)]) == nil)
    }

    @Test func anAccountWhoseFolderIsGoneIsNotASecondAccount() {
        #expect(section(repoID: repo, standings: [
            AccountFixture.standing(AccountFixture.defaultClaude, email: "me@home.com"),
            AccountFixture.standing(AccountFixture.work, email: "me@client.com", exists: false),
        ]) == nil)
    }

    @Test func aLostChoiceShowsEvenWithOneAccountAndWarns() throws {
        let made = try #require(section(
            repoID: repo, project: AgentAccountID("deleted"),
            standings: [AccountFixture.standing(AccountFixture.defaultClaude, email: "me@home.com")]
        ))
        #expect(made.warns)
        #expect(made.title == "me@home.com")
        #expect(made.sentence.contains("the account chosen for the project is not available"))
    }

    @Test func anAgentWithoutAccountsWhoseChoiceIsLostIsCalledUnavailable() throws {
        let made = try #require(section(repoID: repo, project: AgentAccountID("deleted"), provider: .cursor))
        #expect(made.title == AgentAccountLine.unavailableTitle)
        #expect(made.warns)
    }

    @Test func aChatWithNoProjectHasNoSection() {
        #expect(section(repoID: nil) == nil)
        #expect(section(repoID: nil, project: AgentAccountID("deleted")) == nil)
    }

    @Test func theEntriesAreNamedTheSameWayEverywhere() {
        #expect(ComposerAccountSection.heading == "Account")
        #expect(ComposerAccountSection.change == "Change\u{2026}")
    }
}
