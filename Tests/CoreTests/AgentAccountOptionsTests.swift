import Testing
import Foundation
@testable import Core

@Suite("Agent account options")
struct AgentAccountOptionsTests {
    private var standings: [AgentAccountStanding] {
        [
            AccountFixture.standing(AccountFixture.defaultClaude, email: "me@home.com"),
            AccountFixture.standing(AccountFixture.work, email: "me@client.com"),
            AccountFixture.standing(AccountFixture.defaultCodex),
        ]
    }

    private func options(
        project: [AgentKind: AgentAccountID] = [:],
        standings: [AgentAccountStanding]? = nil
    ) -> AgentAccountOptions {
        AgentAccountOptions.make(
            choices: AgentAccountChoices(project: project),
            standings: standings ?? self.standings
        )
    }

    private func group(
        _ provider: AgentKind,
        project: [AgentKind: AgentAccountID] = [:],
        standings: [AgentAccountStanding]? = nil
    ) throws -> AgentAccountOptions.Group {
        try #require(options(project: project, standings: standings).groups.first { $0.provider == provider })
    }

    @Test func aProjectOffersTheAccountsTheAppMadeAndNotTheDefaults() throws {
        let made = options()
        #expect(made.groups.map(\.provider) == [.claudeCode])
        #expect(made.groups[0].entries.map(\.title) == ["me@client.com"])
        #expect(made.groups[0].inherit.title == "Default account")
    }

    @Test func everyGroupOnlyEverOffersItsOwnAgentsAccounts() {
        for group in options(project: [.codex: AccountFixture.defaultCodex.id]).groups {
            #expect(group.entries.allSatisfy { $0.home?.provider == group.provider })
        }
    }

    @Test func eachAgentHoldsItsOwnSelection() throws {
        let both = options(project: [.claudeCode: AccountFixture.work.id, .codex: AccountFixture.defaultCodex.id])
        #expect(both.groups.map(\.provider) == [.claudeCode, .codex])
        #expect(both.groups[0].selected == .account(AccountFixture.work.id))
        #expect(both.groups[1].selected == .account(AccountFixture.defaultCodex.id))
    }

    @Test func nothingStoredSelectsTheDefaultEntry() throws {
        let made = try group(.claudeCode)
        #expect(made.selected == .inherit)
        #expect(made.unavailable == nil)
        #expect(made.chosen(for: made.selected)?.home == nil)
        #expect(made.chosen(for: made.selected)?.provider == .claudeCode)
    }

    @Test func aStoredAccountSelectsItsOwnEntryAndSaysEveryWorkspaceAndChatRunsIt() throws {
        let made = try group(.claudeCode, project: [.claudeCode: AccountFixture.work.id])
        #expect(made.selected == .account(AccountFixture.work.id))
        #expect(made.chosen(for: made.selected)?.home == AccountFixture.work)
        #expect(made.note == "Every workspace and chat in this project runs Claude Code on me@client.com.")
        #expect(!made.warns)
    }

    @Test func anUnavailableEntryIsNotSomethingThatCanBeChosen() throws {
        let made = try group(.claudeCode, project: [.claudeCode: AgentAccountID("deleted")])
        #expect(made.selected == .unavailable)
        #expect(made.chosen(for: .unavailable) == nil)
    }

    @Test func aStoredAccountThatIsGoneSelectsAnUnavailableEntryAndWarns() throws {
        let made = try group(.claudeCode, project: [.claudeCode: AgentAccountID("deleted")])
        #expect(made.unavailable?.title == "Unavailable account")
        #expect(made.note == """
            The account chosen for Claude Code in this project is no longer on this Mac, \
            so every workspace and chat runs its default account.
            """)
        #expect(made.warns)
    }

    @Test func aStoredAccountWhoseDirectoryIsGoneIsUnavailableToo() throws {
        let all = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.work, exists: false),
        ]
        let made = try group(.claudeCode, project: [.claudeCode: AccountFixture.work.id], standings: all)
        #expect(made.selected == .unavailable)
        #expect(made.entries.isEmpty)
        #expect(made.warns)
    }

    @Test func thePickedAccountIsCarriedBackAndNotTheFirstEntryOfTheList() throws {
        let made = try group(.claudeCode, project: [.claudeCode: AccountFixture.defaultClaude.id])
        #expect(made.entries.map(\.home) == [AccountFixture.defaultClaude, AccountFixture.work])
        #expect(made.chosen(for: .account(AccountFixture.work.id))?.home == AccountFixture.work)
    }

    @Test func anAccountOfAnotherAgentIsCarriedBackByNoGroup() throws {
        let made = try group(.claudeCode)
        #expect(made.chosen(for: .account(AccountFixture.defaultCodex.id)) == nil)
    }

    @Test func aProjectThatChoseADefaultAccountStillSelectsAValidEntry() throws {
        let made = try group(.claudeCode, project: [.claudeCode: AccountFixture.defaultClaude.id])
        #expect(made.selected == .account(AccountFixture.defaultClaude.id))
        #expect(made.chosen(for: made.selected)?.home == AccountFixture.defaultClaude)
    }

    @Test func onlyDefaultAccountsMeanOneSentenceForTheWholeProject() {
        let made = options(standings: [AccountFixture.standing(AccountFixture.defaultClaude)])
        #expect(made.groups.isEmpty)
        #expect(made.footer == "Every workspace and chat in this project runs each agent's default account.")
    }

    @Test func aProjectWithGroupsSaysItAllInTheGroups() {
        #expect(options().footer == nil)
    }

    @Test func nothingChosenSaysTheDefaultRunsEverywhere() throws {
        let made = try group(.claudeCode)
        #expect(made.note == "Every workspace and chat in this project runs the default Claude Code account.")
        #expect(!made.warns)
    }

    @Test func noSentenceSpeaksOfAWorkspaceChoosingItsOwn() throws {
        let notes = [
            try group(.claudeCode).note,
            try group(.claudeCode, project: [.claudeCode: AccountFixture.work.id]).note,
            try group(.claudeCode, project: [.claudeCode: AgentAccountID("deleted")]).note,
        ]
        #expect(notes.allSatisfy { !$0.contains("its own") && !$0.contains("this workspace") })
    }

    @Test func aLossOnOneAgentIsNotAWarningOnAnother() throws {
        let gone: [AgentKind: AgentAccountID] = [.claudeCode: AgentAccountID("deleted")]
        #expect(try group(.claudeCode, project: gone).warns)
        #expect(!options(project: gone).groups.contains { $0.provider == .codex })
    }

    @Test func theIsolationDoubtOfAChosenAccountIsInItsOwnGroup() throws {
        let doubtful = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.work, email: "me@client.com", doubt: "Not isolated."),
        ]
        let made = try group(.claudeCode, project: [.claudeCode: AccountFixture.work.id], standings: doubtful)
        #expect(made.note == "Every workspace and chat in this project runs Claude Code on me@client.com. Not isolated.")
    }

    @Test func theDefaultAccountOfAnAgentWithNoEmailIsReferredToWithItsArticle() throws {
        let signedOut = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.defaultCodex),
        ]
        let made = try group(.claudeCode, project: [.claudeCode: AccountFixture.defaultClaude.id], standings: signedOut)
        #expect(made.note == "Every workspace and chat in this project runs Claude Code on the default account.")
    }
}
