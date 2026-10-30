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
        _ scope: AgentAccountOptions.Scope,
        workspace: [AgentKind: AgentAccountID] = [:],
        project: [AgentKind: AgentAccountID] = [:],
        standings: [AgentAccountStanding]? = nil
    ) -> AgentAccountOptions {
        AgentAccountOptions.make(
            scope: scope,
            choices: AgentAccountChoices(workspace: workspace, project: project),
            standings: standings ?? self.standings
        )
    }

    private func group(
        _ provider: AgentKind,
        _ scope: AgentAccountOptions.Scope,
        workspace: [AgentKind: AgentAccountID] = [:],
        project: [AgentKind: AgentAccountID] = [:],
        standings: [AgentAccountStanding]? = nil
    ) throws -> AgentAccountOptions.Group {
        let made = options(scope, workspace: workspace, project: project, standings: standings)
        return try #require(made.groups.first { $0.provider == provider })
    }

    @Test func aProjectOffersTheAccountsTheAppMadeAndNotTheDefaults() throws {
        let made = options(.project)
        #expect(made.groups.map(\.provider) == [.claudeCode])
        #expect(made.groups[0].entries.map(\.title) == ["me@client.com"])
        #expect(made.groups[0].inherit.title == "Default account")
    }

    @Test func aWorkspaceAlsoOffersTheDefaultsSoItCanLeaveAProjectChoice() throws {
        let made = options(.workspace)
        #expect(made.groups.map(\.provider) == [.claudeCode, .codex])
        #expect(made.groups[0].entries.map(\.title) == ["me@home.com", "me@client.com"])
        #expect(made.groups[0].inherit.title == "Same as project")
    }

    @Test func everyGroupOnlyEverOffersItsOwnAgentsAccounts() {
        for scope in [AgentAccountOptions.Scope.project, .workspace] {
            for group in options(scope).groups {
                #expect(group.entries.allSatisfy { $0.home?.provider == group.provider })
            }
        }
    }

    @Test func eachAgentHoldsItsOwnSelectionInTheSameScope() throws {
        let both = options(
            .project,
            project: [.claudeCode: AccountFixture.work.id, .codex: AccountFixture.defaultCodex.id]
        )
        #expect(both.groups.map(\.provider) == [.claudeCode, .codex])
        #expect(both.groups[0].selected == .account(AccountFixture.work.id))
        #expect(both.groups[1].selected == .account(AccountFixture.defaultCodex.id))
    }

    @Test func choosingForOneAgentLeavesTheOtherAgentOnItsDefault() throws {
        let claude = try group(.claudeCode, .workspace, workspace: [.claudeCode: AccountFixture.work.id])
        let codex = try group(.codex, .workspace, workspace: [.claudeCode: AccountFixture.work.id])
        #expect(claude.selected == .account(AccountFixture.work.id))
        #expect(codex.selected == .inherit)
        #expect(codex.note == "Follows the project, which chose no Codex account, so it runs its default account.")
        #expect(!codex.warns)
    }

    @Test func nothingStoredSelectsTheInheritEntry() throws {
        let made = try group(.claudeCode, .project)
        #expect(made.selected == .inherit)
        #expect(made.unavailable == nil)
        #expect(made.chosen(for: made.selected)?.home == nil)
        #expect(made.chosen(for: made.selected)?.provider == .claudeCode)
    }

    @Test func aStoredAccountSelectsItsOwnEntryAndCarriesItsHome() throws {
        let made = try group(.claudeCode, .project, project: [.claudeCode: AccountFixture.work.id])
        #expect(made.selected == .account(AccountFixture.work.id))
        #expect(made.chosen(for: made.selected)?.home == AccountFixture.work)
        #expect(made.note == "Claude Code runs me@client.com in this project.")
        #expect(!made.warns)
    }

    @Test func anUnavailableEntryIsNotSomethingThatCanBeChosen() throws {
        let made = try group(.claudeCode, .project, project: [.claudeCode: AgentAccountID("deleted")])
        #expect(made.selected == .unavailable)
        #expect(made.chosen(for: .unavailable) == nil)
    }

    @Test func aStoredAccountThatIsGoneSelectsAnUnavailableEntryAndWarns() throws {
        let made = try group(.claudeCode, .project, project: [.claudeCode: AgentAccountID("deleted")])
        #expect(made.selected == .unavailable)
        #expect(made.unavailable?.title == "Unavailable account")
        #expect(made.note == """
            The account chosen for Claude Code in this project is no longer on this Mac, \
            so it runs its default account.
            """)
        #expect(made.warns)
    }

    @Test func aStoredAccountWhoseDirectoryIsGoneIsUnavailableToo() throws {
        let all = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.work, exists: false),
        ]
        let made = try group(
            .claudeCode, .project, project: [.claudeCode: AccountFixture.work.id], standings: all
        )
        #expect(made.selected == .unavailable)
        #expect(made.entries.isEmpty)
        #expect(made.warns)
    }

    @Test func aProjectThatChoseADefaultAccountStillSelectsAValidEntry() throws {
        let made = try group(.claudeCode, .project, project: [.claudeCode: AccountFixture.defaultClaude.id])
        #expect(made.selected == .account(AccountFixture.defaultClaude.id))
        #expect(made.chosen(for: made.selected)?.home == AccountFixture.defaultClaude)
    }

    @Test func noAgentWithAnAccountMeansOneSentenceForTheWholeScope() {
        let project = options(.project, standings: [AccountFixture.standing(AccountFixture.defaultClaude)])
        let workspace = options(.workspace, standings: [])
        #expect(project.groups.isEmpty)
        #expect(project.footer == "Agents in this project run their default accounts unless a workspace chooses its own.")
        #expect(workspace.groups.isEmpty)
        #expect(workspace.footer == "Follows the project, which has no account of its own, so agents run their default accounts.")
    }

    @Test func aScopeWithGroupsSaysItAllInTheGroupsAndHasNoFooterOfItsOwn() {
        #expect(options(.project).footer == nil)
        #expect(options(.workspace).footer == nil)
    }

    @Test func nothingChosenAtEitherLevelSaysTheDefaultRuns() throws {
        let project = try group(.claudeCode, .project)
        let workspace = try group(.claudeCode, .workspace)
        #expect(project.note == "Claude Code runs its default account unless a workspace chooses its own.")
        #expect(workspace.note == """
            Follows the project, which chose no Claude Code account, so it runs its default account.
            """)
        #expect(!project.warns && !workspace.warns)
    }

    @Test func aWorkspaceThatChoseNothingSaysWhatTheProjectMakesItRun() throws {
        let made = try group(.claudeCode, .workspace, project: [.claudeCode: AccountFixture.work.id])
        #expect(made.note == "Follows the project, so Claude Code runs me@client.com here.")
        #expect(!made.warns)
    }

    @Test func aWorkspaceChoiceSaysItWasChosenForTheWorkspace() throws {
        let made = try group(
            .claudeCode, .workspace,
            workspace: [.claudeCode: AccountFixture.defaultClaude.id],
            project: [.claudeCode: AccountFixture.work.id]
        )
        #expect(made.selected == .account(AccountFixture.defaultClaude.id))
        #expect(made.note == "Claude Code runs me@home.com in this workspace.")
    }

    @Test func aGoneWorkspaceChoiceSaysItFollowsTheProjectInstead() throws {
        let made = try group(
            .claudeCode, .workspace,
            workspace: [.claudeCode: AgentAccountID("deleted")],
            project: [.claudeCode: AccountFixture.work.id]
        )
        #expect(made.note == """
            The account chosen for Claude Code in this workspace is no longer on this Mac. \
            It follows the project instead.
            """)
        #expect(made.warns)
    }

    @Test func bothGoneSaysTheDefaultRuns() throws {
        let made = try group(
            .claudeCode, .workspace,
            workspace: [.claudeCode: AgentAccountID("a")],
            project: [.claudeCode: AgentAccountID("b")]
        )
        #expect(made.note == """
            The account chosen for Claude Code in this workspace is no longer on this Mac. \
            The project's choice is gone too, so it runs its default account.
            """)
        #expect(made.warns)
    }

    @Test func aGoneProjectChoiceIsSaidToAWorkspaceThatChoseNothing() throws {
        let made = try group(.claudeCode, .workspace, project: [.claudeCode: AgentAccountID("b")])
        #expect(made.note == """
            The account chosen for Claude Code in the project is no longer on this Mac, \
            so it runs its default account.
            """)
        #expect(made.warns)
    }

    @Test func aLossOnOneAgentIsNotAWarningOnAnother() throws {
        let gone: [AgentKind: AgentAccountID] = [.claudeCode: AgentAccountID("deleted")]
        #expect(try group(.claudeCode, .workspace, workspace: gone).warns)
        #expect(try !group(.codex, .workspace, workspace: gone).warns)
    }

    @Test func theIsolationDoubtOfAChosenAccountIsInItsOwnGroup() throws {
        let doubtful = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.work, email: "me@client.com", doubt: "Not isolated."),
        ]
        let made = try group(
            .claudeCode, .project, project: [.claudeCode: AccountFixture.work.id], standings: doubtful
        )
        #expect(made.note == "Claude Code runs me@client.com in this project. Not isolated.")
    }

    @Test func aProjectPickerIgnoresWhatTheWorkspaceChose() throws {
        let made = try group(
            .claudeCode, .project,
            workspace: [.claudeCode: AccountFixture.defaultClaude.id],
            project: [.claudeCode: AccountFixture.work.id]
        )
        #expect(made.selected == .account(AccountFixture.work.id))
    }

    @Test func aWorkspacePickerSelectsTheWorkspaceChoiceAndNotTheProjectOne() throws {
        let made = try group(
            .claudeCode, .workspace,
            workspace: [.claudeCode: AccountFixture.defaultClaude.id],
            project: [.claudeCode: AccountFixture.work.id]
        )
        #expect(made.selected == .account(AccountFixture.defaultClaude.id))
    }

    @Test func theDefaultAccountOfAnAgentWithNoEmailIsReferredToWithItsArticle() throws {
        let signedOut = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.defaultCodex),
        ]
        let chosen = try group(
            .codex, .workspace, workspace: [.codex: AccountFixture.defaultCodex.id], standings: signedOut
        )
        let followed = try group(
            .claudeCode, .workspace, project: [.claudeCode: AccountFixture.defaultClaude.id],
            standings: signedOut
        )
        let atProject = try group(
            .claudeCode, .project, project: [.claudeCode: AccountFixture.defaultClaude.id],
            standings: signedOut
        )

        #expect(chosen.note == "Codex runs the default account in this workspace.")
        #expect(followed.note == "Follows the project, so Claude Code runs the default account here.")
        #expect(atProject.note == "Claude Code runs the default account in this project.")
    }
}
