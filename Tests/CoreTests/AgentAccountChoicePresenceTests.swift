import Testing
import Foundation
@testable import Core

@Suite("Agent account choice and the directory on disk")
struct AgentAccountChoicePresenceTests {
    private let user = URL(filePath: "/Users/someone")

    private func standing(_ home: AgentAccountHome, exists: Bool = true) -> AgentAccountStanding {
        AgentAccountStanding(
            home: home, identity: AgentAccountIdentity(), cliReport: .unanswered,
            isolationDoubt: nil, directoryExists: exists
        )
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

    @Test func aChosenAccountWhoseDirectoryIsGoneFallsToTheDefaultAndReportsTheLoss() {
        let work = extra("work")
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: work.id,
            standings: [standing(defaultClaude), standing(work, exists: false)]
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
        #expect(choice.isProjectChoiceLost)
    }

    @Test func theDefaultAccountRunsEvenWhenItsDirectoryIsNotThereYet() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: nil,
            standings: [standing(defaultClaude, exists: false)]
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
        #expect(!choice.isProjectChoiceLost)
    }

    @Test func theAgentThatOwnsAGoneAccountStillLosesIt() {
        let claudeWork = extra("work")
        let codexWork = extra("work", provider: .codex)
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: claudeWork.id,
            standings: [
                standing(defaultClaude), standing(claudeWork, exists: false),
                standing(defaultCodex), standing(codexWork),
            ]
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.isProjectChoiceLost)
    }

    @Test func anIdThatNoStandingKnowsIsLost() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, project: AgentAccountID("deleted"),
            standings: [standing(defaultClaude)]
        )
        #expect(choice.isProjectChoiceLost)
    }
}
