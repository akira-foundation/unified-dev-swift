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

    @Test func switchingAccountRelaunchesTheProcess() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: defaultClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == true)
        #expect(plan.losesTurnInFlight == false)
        #expect(plan.refusal == nil)
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

    @Test func aSessionThatNeverSpokeIsStillRelaunched() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithoutAgentID, from: defaultClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == true)
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
        #expect(same.directory == nil)
        #expect(refused.losesTurnInFlight == false)
        #expect(refused.directory == nil)
    }

    @Test func aSessionIsRefusedAnAccountOfAProviderItDoesNotRunEvenWhenFromAndToAgree() {
        let codexSession = Session(workspaceID: nil, agentSessionID: "agent-session-1", agentKind: .codex)
        let plan = AgentAccountSwitch.plan(
            session: codexSession, from: defaultClaude, to: workClaude, isTurnInFlight: true
        )
        #expect(plan.relaunch == false)
        #expect(plan.refusal == .otherProvider)
        #expect(plan.directory == nil)
        #expect(plan.losesTurnInFlight == false)
    }

    @Test func aSwitchBetweenAccountsOfDifferentProvidersIsRefusedEvenForASessionOfTheTargetProvider() {
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: workCodex, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == false)
        #expect(plan.refusal == .otherProvider)
    }

    @Test func theProviderGuardComesBeforeTheSameAccountGuard() {
        let codexSession = Session(workspaceID: nil, agentSessionID: "agent-session-1", agentKind: .codex)
        let plan = AgentAccountSwitch.plan(
            session: codexSession, from: workClaude, to: workClaude, isTurnInFlight: false
        )
        #expect(plan.relaunch == false)
        #expect(plan.refusal == .otherProvider)
    }

    @Test func renamingAnAccountDoesNotMakeItAnotherAccount() {
        let renamed = AgentAccountHome(
            provider: workClaude.provider,
            id: workClaude.id,
            directory: workClaude.directory,
            isDefault: workClaude.isDefault,
            label: "Work, renamed"
        )
        let plan = AgentAccountSwitch.plan(
            session: sessionWithAgentID, from: workClaude, to: renamed, isTurnInFlight: true
        )
        #expect(plan.relaunch == false)
        #expect(plan.refusal == nil)
        #expect(plan.losesTurnInFlight == false)
    }
}
