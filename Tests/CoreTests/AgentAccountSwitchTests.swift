import Testing
import Foundation
@testable import Core

@Suite("Moving a live session to another account")
struct AgentAccountSwitchTests {
    private let defaultClaude = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountHome.defaultID(for: .claudeCode),
        directory: URL(filePath: "/Users/test/.claude", directoryHint: .isDirectory),
        isDefault: true
    )
    private let workClaude = AgentAccountHome(
        provider: .claudeCode,
        id: AgentAccountID("work"),
        directory: URL(filePath: "/Users/test/Support/AgentAccounts/claude-code/work", directoryHint: .isDirectory),
        isDefault: false
    )
    private let workCodex = AgentAccountHome(
        provider: .codex,
        id: AgentAccountID("work-codex"),
        directory: URL(filePath: "/Users/test/Support/AgentAccounts/codex/work-codex", directoryHint: .isDirectory),
        isDefault: false
    )
    private let sessionWithAgentID = Session(workspaceID: nil, agentSessionID: "agent-session-1")
    private let sessionWithoutAgentID = Session(workspaceID: nil)

    @Test func switchingAccountRelaunchesTheProcessAndResumesTheAgentSession() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: defaultClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == true)
        #expect(plan.resume == sessionWithAgentID.agentSessionID)
        #expect(plan.losesTurnInFlight == false)
    }

    @Test func switchingDuringATurnSaysTheTurnIsLost() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: defaultClaude, to: workClaude, isTurnInFlight: true
        )
        #expect(plan.losesTurnInFlight == true)
    }

    @Test func switchingToTheSameAccountDoesNothing() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: workClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == false)
        #expect(plan.refusal == nil)
    }

    @Test func switchingToAnAccountOfAnotherProviderIsRefused() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: defaultClaude, to: workCodex, isTurnInFlight: false
        )
        #expect(plan.relaunch == false)
        #expect(plan.refusal == .otherProvider)
    }

    @Test func aSessionWithNoAgentSessionIdRelaunchesWithoutResuming() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithoutAgentID, from: defaultClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == true)
        #expect(plan.resume == nil)
    }

    @Test func theRelaunchPointsAtTheTargetAccountDirectorySoTheTranscriptsDoNotMix() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: defaultClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.directory == workClaude.directory)
        #expect(plan.directory != defaultClaude.directory)
    }

    @Test func aSwitchThatDoesNotRelaunchLosesNoTurnAndCarriesNothingToRelaunchWith() {
        let same = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: workClaude, to: workClaude, isTurnInFlight: true
        )
        let refused = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: defaultClaude, to: workCodex, isTurnInFlight: true
        )
        #expect(same.losesTurnInFlight == false)
        #expect(same.resume == nil)
        #expect(same.directory == nil)
        #expect(refused.losesTurnInFlight == false)
        #expect(refused.resume == nil)
        #expect(refused.directory == nil)
    }
}
