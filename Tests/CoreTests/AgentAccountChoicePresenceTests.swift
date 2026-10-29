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
            provider: .claudeCode, workspace: work.id, project: nil,
            standings: [standing(defaultClaude), standing(work, exists: false)]
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
        #expect(choice.lost == [.workspace])
        #expect(choice.foreign == [])
        #expect(choice.lostForGood == [.workspace])
    }

    @Test func aWorkspaceChoiceWhoseDirectoryIsGoneFallsToTheProjectChoice() {
        let work = extra("work")
        let personal = extra("personal")
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: work.id, project: personal.id,
            standings: [standing(defaultClaude), standing(work, exists: false), standing(personal)]
        )
        #expect(choice.home?.id == personal.id)
        #expect(choice.reason == .project)
        #expect(choice.lost == [.workspace])
    }

    @Test func theDefaultAccountRunsEvenWhenItsDirectoryIsNotThereYet() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: nil, project: nil,
            standings: [standing(defaultClaude, exists: false)]
        )
        #expect(choice.home?.id == defaultClaude.id)
        #expect(choice.reason == .providerDefault)
        #expect(choice.lost == [])
    }

    @Test func aChoiceOfAnotherAgentIsLostForThisOneButNotLostForGood() {
        let work = extra("work")
        let choice = AgentAccountChoice.resolve(
            provider: .codex, workspace: nil, project: work.id,
            standings: [standing(defaultClaude), standing(work), standing(defaultCodex)]
        )
        #expect(choice.home?.id == defaultCodex.id)
        #expect(choice.lost == [.project])
        #expect(choice.foreign == [.project])
        #expect(choice.lostForGood == [])
    }

    @Test func aChoiceOfAnotherAgentWhoseDirectoryIsGoneIsLostForGood() {
        let work = extra("work")
        let choice = AgentAccountChoice.resolve(
            provider: .codex, workspace: nil, project: work.id,
            standings: [standing(defaultClaude), standing(work, exists: false), standing(defaultCodex)]
        )
        #expect(choice.lost == [.project])
        #expect(choice.foreign == [])
        #expect(choice.lostForGood == [.project])
    }

    @Test func anIdThatNoStandingKnowsIsLostForGood() {
        let choice = AgentAccountChoice.resolve(
            provider: .claudeCode, workspace: AgentAccountID("deleted"), project: nil,
            standings: [standing(defaultClaude)]
        )
        #expect(choice.lostForGood == [.workspace])
    }
}
