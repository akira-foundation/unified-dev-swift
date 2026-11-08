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

    @Test func theProjectChoiceApplies() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: work.id, standings: both
        )
        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .project)
        #expect(!choice.isProjectChoiceLost)
    }

    @Test func theProviderDefaultAppliesWhenNothingChose() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: nil, standings: both
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
        #expect(!choice.isProjectChoiceLost)
    }

    @Test func aProjectChoiceThatIsGoneFallsToTheDefaultAndReportsIt() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: AgentAccountID("deleted"), standings: both
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
        #expect(choice.isProjectChoiceLost)
    }

    @Test func aChoiceForAProviderWithNoAccountAtAllResolvesToNothing() {
        let choice = AgentAccountChoice.resolve(
            provider: .cursor, project: nil, standings: both
        )
        #expect(choice.home == nil)
        #expect(choice.reason == .noAccount)
        #expect(!choice.isProjectChoiceLost)
    }

    @Test func aLostChoiceWithNothingToFallBackOnIsStillReported() {
        let choice = AgentAccountChoice.resolve(
            provider: .cursor, project: AgentAccountID("deleted"), standings: both
        )
        #expect(choice.home == nil)
        #expect(choice.reason == .noAccount)
        #expect(choice.isProjectChoiceLost)
    }

    @Test func anIdThatTwoProvidersShareIsResolvedWithinTheAskedProvider() {
        let codexWork = extra("work", provider: .codex)
        let standings = [defaultClaude, work, defaultCodex, codexWork].map(standing)
        let choice = AgentAccountChoice.resolve(
            provider: .codex, project: work.id, standings: standings
        )
        #expect(choice.home?.provider == .codex)
        #expect(choice.home?.directory == codexWork.directory)
        #expect(choice.reason == .project)
        #expect(!choice.isProjectChoiceLost)
    }

    @Test func theDefaultIsNotPickedByPositionInTheList() {
        let standings = [work, personal, defaultClaude].map(standing)
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: nil, standings: standings
        )
        #expect(choice.home?.id == defaultClaude.id)
    }

    @Test func aChosenAccountIsFoundWhetherOrNotItsCliAnswers() {
        let silent = AgentAccountStanding(
            home: work, identity: AgentAccountIdentity(), cliReport: .claimsNoSession, isolationDoubt: "doubt"
        )
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: work.id, standings: [standing(defaultClaude), silent]
        )
        #expect(choice.home?.id == work.id)
        #expect(choice.reason == .project)
        #expect(!choice.isProjectChoiceLost)
    }
}
