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

    @Test func aProjectOffersTheAccountsTheAppMadeAndNotTheDefaults() {
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: nil, standings: standings)
        #expect(options.groups.map(\.provider) == [.claudeCode])
        #expect(options.groups[0].entries.map(\.title) == ["me@client.com"])
        #expect(options.inherit.title == "Default accounts")
    }

    @Test func aWorkspaceAlsoOffersTheDefaultsSoItCanLeaveAProjectChoice() {
        let options = AgentAccountOptions.make(scope: .workspace, workspace: nil, project: nil, standings: standings)
        #expect(options.groups.map(\.provider) == [.claudeCode, .codex])
        #expect(options.groups[0].entries.map(\.title) == ["me@home.com", "me@client.com"])
        #expect(options.inherit.title == "Same as project")
    }

    @Test func nothingStoredSelectsTheInheritEntry() {
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: nil, standings: standings)
        #expect(options.selected == .inherit)
        #expect(options.unavailable == nil)
        #expect(options.entry(for: options.selected)?.home == nil)
    }

    @Test func aStoredAccountSelectsItsOwnEntryAndCarriesItsHome() {
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: AccountFixture.work.id, standings: standings)
        #expect(options.selected == .account(AccountFixture.work.id))
        #expect(options.entry(for: options.selected)?.home == AccountFixture.work)
        #expect(options.footer == "Claude Code runs me@client.com in this project.")
        #expect(!options.warns)
    }

    @Test func aStoredAccountThatIsGoneSelectsAnUnavailableEntryAndWarns() {
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: AgentAccountID("deleted"), standings: standings)
        #expect(options.selected == .unavailable)
        #expect(options.unavailable?.title == "Unavailable account")
        #expect(options.footer == "The account chosen for this project is no longer on this Mac, so agents run their default accounts.")
        #expect(options.warns)
    }

    @Test func aStoredAccountWhoseDirectoryIsGoneIsUnavailableToo() {
        let all = [AccountFixture.standing(AccountFixture.defaultClaude), AccountFixture.standing(AccountFixture.work, exists: false)]
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: AccountFixture.work.id, standings: all)
        #expect(options.selected == .unavailable)
        #expect(options.groups.flatMap(\.entries).isEmpty)
        #expect(options.warns)
    }

    @Test func aProjectThatChoseADefaultAccountStillSelectsAValidEntry() {
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: AccountFixture.defaultClaude.id, standings: standings)
        #expect(options.selected == .account(AccountFixture.defaultClaude.id))
        #expect(options.entry(for: options.selected) != nil)
    }

    @Test func nothingChosenAtEitherLevelSaysTheDefaultsRun() {
        let project = AgentAccountOptions.make(scope: .project, workspace: nil, project: nil, standings: standings)
        let workspace = AgentAccountOptions.make(scope: .workspace, workspace: nil, project: nil, standings: standings)
        #expect(project.footer == "Agents in this project run their default accounts unless a workspace chooses its own.")
        #expect(workspace.footer == "Follows the project, which has no account of its own, so agents run their default accounts.")
        #expect(!project.warns && !workspace.warns)
    }

    @Test func aWorkspaceThatChoseNothingSaysWhatTheProjectMakesItRun() {
        let options = AgentAccountOptions.make(scope: .workspace, workspace: nil, project: AccountFixture.work.id, standings: standings)
        #expect(options.footer == "Follows the project, so Claude Code runs me@client.com here.")
        #expect(!options.warns)
    }

    @Test func aWorkspaceChoiceSaysItWasChosenForTheWorkspace() {
        let options = AgentAccountOptions.make(scope: .workspace, workspace: AccountFixture.defaultClaude.id, project: AccountFixture.work.id, standings: standings)
        #expect(options.selected == .account(AccountFixture.defaultClaude.id))
        #expect(options.footer == "Claude Code runs me@home.com in this workspace.")
    }

    @Test func aGoneWorkspaceChoiceSaysItFollowsTheProjectInstead() {
        let options = AgentAccountOptions.make(scope: .workspace, workspace: AgentAccountID("deleted"), project: AccountFixture.work.id, standings: standings)
        #expect(options.footer == "The account chosen for this workspace is no longer on this Mac. It follows the project instead.")
        #expect(options.warns)
    }

    @Test func bothGoneSaysTheDefaultsRun() {
        let options = AgentAccountOptions.make(scope: .workspace, workspace: AgentAccountID("a"), project: AgentAccountID("b"), standings: standings)
        #expect(options.footer == "The account chosen for this workspace is no longer on this Mac. The project's choice is gone too, so agents run their default accounts.")
        #expect(options.warns)
    }

    @Test func aGoneProjectChoiceIsSaidToAWorkspaceThatChoseNothing() {
        let options = AgentAccountOptions.make(scope: .workspace, workspace: nil, project: AgentAccountID("b"), standings: standings)
        #expect(options.footer == "The account chosen for the project is no longer on this Mac, so agents run their default accounts.")
        #expect(options.warns)
    }

    @Test func theIsolationDoubtOfAChosenAccountIsInTheFooter() {
        let doubtful = [AccountFixture.standing(AccountFixture.defaultClaude), AccountFixture.standing(AccountFixture.work, email: "me@client.com", doubt: "Not isolated.")]
        let options = AgentAccountOptions.make(scope: .project, workspace: nil, project: AccountFixture.work.id, standings: doubtful)
        #expect(options.footer == "Claude Code runs me@client.com in this project. Not isolated.")
    }

    @Test func aProjectPickerIgnoresWhatTheWorkspaceChose() {
        let options = AgentAccountOptions.make(
            scope: .project, workspace: AccountFixture.defaultClaude.id, project: AccountFixture.work.id, standings: standings
        )
        #expect(options.selected == .account(AccountFixture.work.id))
    }

    @Test func aWorkspacePickerSelectsTheWorkspaceChoiceAndNotTheProjectOne() {
        let options = AgentAccountOptions.make(
            scope: .workspace, workspace: AccountFixture.defaultClaude.id, project: AccountFixture.work.id, standings: standings
        )
        #expect(options.selected == .account(AccountFixture.defaultClaude.id))
    }

    @Test func theDefaultAccountOfAnAgentWithNoEmailIsReferredToWithItsArticle() {
        let signedOut = [
            AccountFixture.standing(AccountFixture.defaultClaude),
            AccountFixture.standing(AccountFixture.defaultCodex),
        ]
        let chosen = AgentAccountOptions.make(
            scope: .workspace, workspace: AccountFixture.defaultCodex.id, project: nil, standings: signedOut
        )
        let followed = AgentAccountOptions.make(
            scope: .workspace, workspace: nil, project: AccountFixture.defaultClaude.id, standings: signedOut
        )
        let atProject = AgentAccountOptions.make(
            scope: .project, workspace: nil, project: AccountFixture.defaultClaude.id, standings: signedOut
        )

        #expect(chosen.footer == "Codex runs the default account in this workspace.")
        #expect(followed.footer == "Follows the project, so Claude Code runs the default account here.")
        #expect(atProject.footer == "Claude Code runs the default account in this project.")
    }
}
