import Testing
import Foundation
@testable import Core

@Suite("A deliberate switch waiting for the next delivery")
struct AgentPendingSwitchTests {
    private let defaultClaude = AccountFixture.defaultClaude
    private let work = AccountFixture.work
    private let reuses: [AgentRunnerReuse] = [.build, .reuse, .settleThenReuse, .retireThenBuild]
    private let purposes: [AgentSessionSettlement.Purpose] = [.sending, .answering]

    private func pending(_ home: AgentAccountHome? = nil) -> AgentPendingSwitch {
        var made = AgentPendingSwitch()
        made.intend(home ?? work)
        return made
    }

    @Test func aPendingSwitchToTheAccountAboutToRunIsDeliberateAndLaunchesFromThePendingHome() {
        let elsewhere = URL(filePath: "/elsewhere/work", directoryHint: .isDirectory)
        let home = AgentAccountHome(provider: .claudeCode, id: work.id, directory: elsewhere, isDefault: false)
        let launch = pending(home).launch(resolved: work)
        #expect(launch.isDeliberateSwitch)
        #expect(launch.account?.directory == elsewhere)
    }

    @Test func aPendingSwitchToAnotherAccountThanTheOneResolvedIsStaleAndIgnored() {
        let launch = pending().launch(resolved: defaultClaude)
        #expect(!launch.isDeliberateSwitch)
        #expect(launch.account == defaultClaude)
    }

    @Test func withNothingPendingTheResolvedAccountRunsAndIsNotADeliberateSwitch() {
        let none = AgentPendingSwitch()
        #expect(none.launch(resolved: work) == .init(account: work, isDeliberateSwitch: false))
        #expect(none.launch(resolved: nil) == .init(account: nil, isDeliberateSwitch: false))
        #expect(pending().launch(resolved: nil) == .init(account: nil, isDeliberateSwitch: false))
    }

    @Test func theSwitchIsConsumedWheneverASettlementWasAppliedForASend() {
        for reuse in [AgentRunnerReuse.build, .settleThenReuse, .retireThenBuild] {
            var waiting = pending()
            waiting.settled(by: reuse, for: .sending)
            #expect(waiting.destination == nil)
        }
    }

    @Test func aQuestionNeverConsumesTheSwitchWhateverTheDecision() {
        for reuse in reuses {
            var waiting = pending()
            waiting.settled(by: reuse, for: .answering)
            #expect(waiting.destination?.id == work.id)
        }
    }

    @Test func aSendThatReusedASettledRunnerLeavesTheSwitchWhereItWas() {
        var waiting = pending()
        waiting.settled(by: .reuse, for: .sending)
        #expect(waiting.destination?.id == work.id)
    }

    @Test func droppingForgetsTheSwitchAndIntendingReplacesIt() {
        var waiting = pending()
        waiting.drop()
        #expect(waiting.destination == nil)
        waiting.intend(work)
        waiting.intend(defaultClaude)
        #expect(waiting.destination?.id == defaultClaude.id)
    }
}
