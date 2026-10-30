import Testing
import Foundation
@testable import Core

@Suite("Whether an agent may be opened for this call at all")
struct AgentDeliveryGateTests {
    @Test func aSendIsRefusedForAnArchivingWorkspaceBeforeAnythingElse() {
        #expect(AgentDeliveryGate.decide(purpose: .sending, isArchiving: true, isHeld: false)
            == .refuse("The workspace is being archived."))
        #expect(AgentDeliveryGate.decide(purpose: .sending, isArchiving: true, isHeld: true)
            == .refuse("The workspace is being archived."))
    }

    @Test func aSendIsRefusedWhileAnInterruptedRewindHoldsTheWorkspace() {
        #expect(AgentDeliveryGate.decide(purpose: .sending, isArchiving: false, isHeld: true)
            == .refuse("Resolve the interrupted rewind before sending more messages."))
    }

    @Test func aSendProceedsWhenNothingHoldsTheWorkspace() {
        #expect(AgentDeliveryGate.decide(purpose: .sending, isArchiving: false, isHeld: false) == .proceed)
    }

    @Test func aQuestionStillProceedsDuringARewindBecauseTheRecoveryIsTheQuestion() {
        #expect(AgentDeliveryGate.decide(purpose: .answering, isArchiving: false, isHeld: true) == .proceed)
        #expect(AgentDeliveryGate.decide(purpose: .answering, isArchiving: false, isHeld: false) == .proceed)
    }

    @Test func aQuestionIsRefusedForAnArchivingWorkspaceLikeASend() {
        #expect(AgentDeliveryGate.decide(purpose: .answering, isArchiving: true, isHeld: true)
            == .refuse("The workspace is being archived."))
        #expect(AgentDeliveryGate.decide(purpose: .answering, isArchiving: true, isHeld: false)
            == .refuse("The workspace is being archived."))
    }
}
