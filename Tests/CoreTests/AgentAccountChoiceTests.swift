import Testing
import Foundation
@testable import Core

@Suite("Agent account choice")
struct AgentAccountChoiceTests {
    private let user = URL(filePath: "/Users/someone")

    private func standing(_ home: AgentAccountHome) -> AgentAccountStanding {
        AgentAccountStanding(home: home, identity: AgentAccountIdentity(), cliReport: .unanswered, isolationDoubt: nil)
    }

    private func extra(_ name: String, provider: AgentKind = .claudeCode) -> AgentAccountHome {
        AgentAccountHome(
            provider: provider,
            id: AgentAccountID(name),
            directory: URL(filePath: "/support/\(provider.rawValue)/\(name)", directoryHint: .isDirectory),
            isDefault: false
        )
    }

    private var defaultClaude: AgentAccountHome { AgentAccountHome.defaultHome(for: .claudeCode, home: user)! }
    private var defaultCodex: AgentAccountHome { AgentAccountHome.defaultHome(for: .codex, home: user)! }
    private var work: AgentAccountHome { extra("work") }
    private var personal: AgentAccountHome { extra("personal") }

    private var both: [AgentAccountStanding] {
        [defaultClaude, work, personal, defaultCodex].map(standing)
    }

    @Test func theWorkspaceChoiceBeatsTheProjectChoice() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: personal.id, project: work.id, standings: both
        )
        #expect(choice.home?.id == personal.id)
        #expect(choice.reason == .workspace)
    }

    @Test func theProjectChoiceAppliesWhenTheWorkspaceHasNone() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: nil, project: work.id, standings: both
        )
        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .project)
    }

    @Test func theProviderDefaultAppliesWhenNothingChose() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: nil, project: nil, standings: both
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
    }

    @Test func aChoiceNamingAnAccountThatIsGoneFallsBackToTheDefaultAndSaysSo() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: nil, project: AgentAccountID("deleted"), standings: both
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .chosenAccountIsGone)
    }

    @Test func aWorkspaceChoiceThatIsGoneSaysSoEvenWhenTheProjectChoiceStands() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: AgentAccountID("deleted"), project: work.id, standings: both
        )
        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .chosenAccountIsGone)
    }

    @Test func whenBothChoicesAreGoneTheDefaultRunsAndTheReasonStillWarns() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: AgentAccountID("deleted"), project: AgentAccountID("also-deleted"), standings: both
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .chosenAccountIsGone)
    }

    @Test func aWorkspaceChoiceOfAnotherProviderFallsToTheProjectChoice() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: defaultCodex.id, project: work.id, standings: both
        )
        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .chosenAccountIsGone)
    }

    @Test func aChoiceForAProviderWithNoAccountAtAllResolvesToNothing() {
        let choice = AgentAccountChoice.resolve(
            provider: .cursor, workspace: nil, project: nil, standings: both
        )
        #expect(choice.home == nil)
        #expect(choice.reason == .noAccount)
    }

    @Test func aLostChoiceWithNothingToFallBackOnStillSaysItWasLost() {
        let choice = AgentAccountChoice.resolve(
            provider: .cursor, workspace: AgentAccountID("deleted"), project: nil, standings: both
        )
        #expect(choice.home == nil)
        #expect(choice.reason == .chosenAccountIsGone)
    }

    @Test func aChoiceNamingAnAccountOfAnotherProviderIsTreatedAsLost() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: defaultCodex.id, project: nil, standings: both
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .chosenAccountIsGone)
    }

    @Test func anIdThatTwoProvidersShareIsResolvedWithinTheAskedProvider() {
        let codexWork = extra("work", provider: .codex)
        let standings = [defaultClaude, work, defaultCodex, codexWork].map(standing)
        let choice = AgentAccountChoice.resolve(
            provider: .codex, workspace: nil, project: work.id, standings: standings
        )
        #expect(choice.home?.provider == .codex)
        #expect(choice.home?.directory == codexWork.directory)
        #expect(choice.reason == .project)
    }

    @Test func theDefaultIsNotPickedByPositionInTheList() {
        let standings = [work, personal, defaultClaude].map(standing)
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: nil, project: nil, standings: standings
        )
        #expect(choice.home?.id == defaultClaude.id)
    }

    @Test func aChosenAccountIsFoundWhetherOrNotItsCliAnswers() {
        let silent = AgentAccountStanding(
            home: work, identity: AgentAccountIdentity(), cliReport: .claimsNoSession, isolationDoubt: "doubt"
        )
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: work.id, project: nil, standings: [standing(defaultClaude), silent]
        )
        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .workspace)
    }
}
