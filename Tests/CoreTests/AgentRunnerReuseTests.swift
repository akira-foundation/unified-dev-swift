import Testing
import Foundation
@testable import Core

@Suite("Whether a runner already built may serve the next call")
struct AgentRunnerReuseTests {
    private let purposes: [AgentSessionSettlement.Purpose] = [.sending, .answering]

    private func decide(
        hasRunner: Bool = true,
        changed: Bool = false,
        settled: Bool = false,
        purpose: AgentSessionSettlement.Purpose = .sending,
        clears: Bool = false
    ) -> AgentRunnerReuse {
        AgentRunnerReuse.decide(
            hasRunner: hasRunner,
            preferencesChanged: changed,
            isSettled: settled,
            purpose: purpose,
            settlementClearsStoredID: clears
        )
    }

    @Test func withNoRunnerOneIsAlwaysBuilt() {
        for purpose in purposes {
            for changed in [true, false] {
                for settled in [true, false] {
                    for clears in [true, false] {
                        #expect(decide(hasRunner: false, changed: changed, settled: settled, purpose: purpose, clears: clears) == .build)
                    }
                }
            }
        }
    }

    @Test func aRunnerBuiltForOtherPreferencesIsRetiredWhateverElseIsTrue() {
        for purpose in purposes {
            for settled in [true, false] {
                for clears in [true, false] {
                    #expect(decide(changed: true, settled: settled, purpose: purpose, clears: clears) == .retireThenBuild)
                }
            }
        }
    }

    @Test func aQuestionReusesTheRunnerAndNeverSettlesNorRetiresItEvenIfTheSettlementWouldClear() {
        for settled in [true, false] {
            for clears in [true, false] {
                #expect(decide(settled: settled, purpose: .answering, clears: clears) == .reuse)
            }
        }
    }

    @Test func aSettledRunnerServingASendIsReusedAsItIs() {
        #expect(decide(settled: true, purpose: .sending, clears: false) == .reuse)
        #expect(decide(settled: true, purpose: .sending, clears: true) == .reuse)
    }

    @Test func anUnsettledRunnerThatTheSettlementWouldClearIsRetiredBeforeItServesASend() {
        #expect(decide(settled: false, purpose: .sending, clears: true) == .retireThenBuild)
    }

    @Test func anUnsettledRunnerThatTheSettlementOnlyRecordsIsSettledAndReused() {
        #expect(decide(settled: false, purpose: .sending, clears: false) == .settleThenReuse)
    }

    @Test func aSettlementIsAppliedForEveryDecisionExceptReuseAndNeverForAQuestion() {
        #expect(AgentRunnerReuse.build.appliesSettlement(for: .sending))
        #expect(AgentRunnerReuse.retireThenBuild.appliesSettlement(for: .sending))
        #expect(AgentRunnerReuse.settleThenReuse.appliesSettlement(for: .sending))
        #expect(!AgentRunnerReuse.reuse.appliesSettlement(for: .sending))
        for reuse in [AgentRunnerReuse.build, .retireThenBuild, .settleThenReuse, .reuse] {
            #expect(!reuse.appliesSettlement(for: .answering))
        }
    }

    @Test func onlyReuseAndSettleThenReuseKeepTheRunner() {
        #expect(AgentRunnerReuse.reuse.keepsRunner)
        #expect(AgentRunnerReuse.settleThenReuse.keepsRunner)
        #expect(!AgentRunnerReuse.build.keepsRunner)
        #expect(!AgentRunnerReuse.retireThenBuild.keepsRunner)
    }
}
