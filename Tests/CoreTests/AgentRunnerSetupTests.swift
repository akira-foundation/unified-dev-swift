import Testing
import Foundation
@testable import Core

@Suite("What opening or reusing a runner does, decided in one place")
struct AgentRunnerSetupTests {
    private let switching = AgentSessionSettlement(
        recordedAccount: nil,
        switchTarget: SessionSegmentTarget(agentKind: .claudeCode, accountID: AccountFixture.work.id, model: "", effort: "")
    )
    private let recording = AgentSessionSettlement(recordedAccount: AccountFixture.work.id, switchTarget: nil)

    private func decide(
        gate: AgentDeliveryGate = .proceed,
        hasRunner: Bool = true,
        changed: Bool = false,
        settled: Bool = false,
        purpose: AgentSessionSettlement.Purpose = .sending,
        settlement: AgentSessionSettlement? = nil
    ) -> AgentRunnerSetup {
        AgentRunnerSetup.decide(
            gate: gate,
            hasRunner: hasRunner,
            preferencesChanged: changed,
            isSettled: settled,
            purpose: purpose,
            settlement: settlement ?? recording
        )
    }

    private func plan(_ setup: AgentRunnerSetup) -> AgentRunnerSetup.Plan? {
        guard case .ready(let plan) = setup else { return nil }
        return plan
    }

    @Test func aRefusedGateRefusesWhateverElseIsTrueAndCarriesNoSettlement() {
        for hasRunner in [true, false] {
            for purpose in [AgentSessionSettlement.Purpose.sending, .answering] {
                let setup = decide(gate: .refuse("no"), hasRunner: hasRunner, purpose: purpose, settlement: switching)
                #expect(setup == .refused("no"))
            }
        }
    }

    @Test func aSendThatBuildsAppliesTheSettlementAndLeavesTheRunnerSettled() {
        let built = plan(decide(hasRunner: false, settlement: switching))
        #expect(built?.reuse == .build)
        #expect(built?.settlement == switching)
        #expect(built?.isSettledAfterwards == true)
        #expect(built?.retiresRunner == false)
        #expect(built?.keepsRunner == false)
    }

    @Test func aQuestionThatBuildsAppliesNothingAndLeavesTheRunnerUnsettled() {
        let built = plan(decide(hasRunner: false, settled: true, purpose: .answering, settlement: switching))
        #expect(built?.settlement == .nothing)
        #expect(built?.isSettledAfterwards == false)
    }

    @Test func aSettledRunnerServingASendIsReusedWithNothingToApplyAndStaysSettled() {
        let reused = plan(decide(settled: true, settlement: recording))
        #expect(reused?.reuse == .reuse)
        #expect(reused?.settlement == .nothing)
        #expect(reused?.isSettledAfterwards == true)
        #expect(reused?.keepsRunner == true)
        #expect(reused?.retiresRunner == false)
    }

    @Test func aQuestionServedByAnUnsettledRunnerLeavesItUnsettled() {
        let reused = plan(decide(settled: false, purpose: .answering, settlement: switching))
        #expect(reused?.reuse == .reuse)
        #expect(reused?.settlement == .nothing)
        #expect(reused?.isSettledAfterwards == false)
        #expect(reused?.retiresRunner == false)
        #expect(reused?.keepsRunner == true)
    }

    @Test func anUnsettledRunnerThatTheSettlementWouldSwitchIsRetiredThenBuiltWithTheSettlementApplied() {
        let retired = plan(decide(settled: false, settlement: switching))
        #expect(retired?.reuse == .retireThenBuild)
        #expect(retired?.retiresRunner == true)
        #expect(retired?.keepsRunner == false)
        #expect(retired?.settlement == switching)
        #expect(retired?.isSettledAfterwards == true)
    }

    @Test func anUnsettledRunnerThatTheSettlementOnlyRecordsIsKeptAndSettled() {
        let kept = plan(decide(settled: false, settlement: recording))
        #expect(kept?.reuse == .settleThenReuse)
        #expect(kept?.keepsRunner == true)
        #expect(kept?.retiresRunner == false)
        #expect(kept?.settlement == recording)
        #expect(kept?.isSettledAfterwards == true)
    }

    @Test func aRunnerBuiltForOtherPreferencesIsRetiredAndTheSettlementIsApplied() {
        let retired = plan(decide(changed: true, settled: true, settlement: recording))
        #expect(retired?.retiresRunner == true)
        #expect(retired?.keepsRunner == false)
        #expect(retired?.settlement == recording)
    }
}
