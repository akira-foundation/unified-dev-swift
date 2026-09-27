import Testing
import Foundation
@testable import Core

@Suite("Onboarding flow")
struct OnboardingFlowTests {
    @Test("Four steps in the assistant's order, and only two of them can be dropped")
    func order() {
        #expect(OnboardingStep.order == [.greeting, .checks, .agent, .extras])
        #expect(OnboardingStep.order == OnboardingStep.allCases)
        #expect(!OnboardingStep.greeting.isOptional)
        #expect(!OnboardingStep.checks.isOptional)
        #expect(OnboardingStep.agent.isOptional)
        #expect(OnboardingStep.extras.isOptional)
    }

    @Test("A machine with nothing to offer walks the greeting and the checks alone")
    func withoutAnyOffer() {
        let flow = OnboardingFlow(step: .greeting)
        #expect(flow.steps == [.greeting, .checks])
        #expect(flow.next == .checks)
        #expect(!flow.isOffered(.agent))
        #expect(!flow.isOffered(.extras))
        #expect(flow.forwardButtonTitle == OnboardingFlow.startTitle)

        let checks = OnboardingFlow(step: .checks)
        #expect(checks.next == nil)
        #expect(checks.isLastStep)
        #expect(checks.forwardButtonTitle == OnboardingFlow.finishTitle)
    }

    @Test("The agent choice on its own lands between the checks and the end")
    func withTheAgentChoiceAlone() {
        let flow = OnboardingFlow(step: .checks, offersAgentChoice: true)
        #expect(flow.steps == [.greeting, .checks, .agent])
        #expect(flow.next == .agent)
        #expect(!flow.isLastStep)
        #expect(flow.forwardButtonTitle == OnboardingFlow.forwardTitle)

        let agent = OnboardingFlow(step: .agent, offersAgentChoice: true)
        #expect(agent.isLastStep)
        #expect(agent.back == .checks)
        #expect(agent.forwardButtonTitle == OnboardingFlow.finishTitle)
    }

    @Test("The extras on their own follow the checks, with the agent choice skipped")
    func withTheExtrasAlone() {
        let flow = OnboardingFlow(step: .checks, offersExtras: true)
        #expect(flow.steps == [.greeting, .checks, .extras])
        #expect(flow.next == .extras)
        #expect(flow.isOffered(.extras))
        #expect(!flow.isOffered(.agent))

        let extras = OnboardingFlow(step: .extras, offersExtras: true)
        #expect(extras.back == .checks)
        #expect(extras.isLastStep)
        #expect(extras.forwardButtonTitle == OnboardingFlow.finishTitle)
    }

    @Test("Both offers give the whole sequence")
    func withBothOffers() {
        let flow = OnboardingFlow(step: .greeting, offersAgentChoice: true, offersExtras: true)
        #expect(flow.steps == [.greeting, .checks, .agent, .extras])
        #expect(flow.isOffered(.agent))
        #expect(flow.isOffered(.extras))
    }

    @Test("The mutators turn each offer on and off after the window has opened")
    func offering() {
        var flow = OnboardingFlow(step: .greeting)
        #expect(flow.steps == [.greeting, .checks])

        flow.offerAgentChoice(true)
        #expect(flow.offersAgentChoice)
        #expect(flow.steps == [.greeting, .checks, .agent])

        flow.offerExtras(true)
        #expect(flow.offersExtras)
        #expect(flow.steps == [.greeting, .checks, .agent, .extras])

        flow.offerAgentChoice(false)
        #expect(!flow.offersAgentChoice)
        #expect(flow.steps == [.greeting, .checks, .extras])
    }

    @Test("The step somebody is standing on stays in the sequence when the offer is withdrawn")
    func theStandingStepSurvivesAWithdrawnOffer() {
        var flow = OnboardingFlow(step: .checks, offersAgentChoice: true, offersExtras: true)
        let movedToTheAgent = flow.advance()
        #expect(movedToTheAgent)
        #expect(flow.step == .agent)

        flow.offerAgentChoice(false)
        #expect(flow.steps == [.greeting, .checks, .agent, .extras])
        #expect(flow.step == .agent)
        #expect(flow.next == .extras)
        #expect(flow.back == .checks)
    }

    @Test("A first run opens on the greeting, and every other reason opens on the checks")
    func opening() {
        #expect(OnboardingFlow.firstStep(trigger: .firstRun) == .greeting)
        #expect(OnboardingFlow.firstStep(trigger: .blocked) == .checks)
        #expect(OnboardingFlow.firstStep(trigger: .none) == .checks)
    }

    @Test("Advancing walks the longest sequence and then refuses")
    func advancing() {
        var flow = OnboardingFlow(step: .greeting, offersAgentChoice: true, offersExtras: true)
        for expected in [OnboardingStep.checks, .agent, .extras] {
            let moved = flow.advance()
            #expect(moved)
            #expect(flow.step == expected)
        }
        let refused = flow.advance()
        #expect(!refused)
        #expect(flow.step == .extras)
    }

    @Test("Going back walks the longest sequence to the greeting and then refuses")
    func goingBack() {
        var flow = OnboardingFlow(step: .extras, offersAgentChoice: true, offersExtras: true)
        for expected in [OnboardingStep.agent, .checks, .greeting] {
            let wentBack = flow.goBack()
            #expect(wentBack)
            #expect(flow.step == expected)
        }
        #expect(!flow.canGoBack)
        let refused = flow.goBack()
        #expect(!refused)
        #expect(flow.step == .greeting)
    }

    @Test("The greeting invites, the steps after it continue, and the last one ends setup")
    func forwardTitles() {
        #expect(OnboardingFlow.startTitle == "Get started")
        #expect(OnboardingFlow.forwardTitle == "Continue")

        let greeting = OnboardingFlow(step: .greeting, offersAgentChoice: true, offersExtras: true)
        #expect(!greeting.isLastStep)
        #expect(greeting.forwardButtonTitle == OnboardingFlow.startTitle)

        for step in [OnboardingStep.checks, .agent] {
            let standing = OnboardingFlow(step: step, offersAgentChoice: true, offersExtras: true)
            #expect(!standing.isLastStep)
            #expect(standing.forwardButtonTitle == OnboardingFlow.forwardTitle)
        }
        let last = OnboardingFlow(step: .extras, offersAgentChoice: true, offersExtras: true)
        #expect(last.isLastStep)
        #expect(last.steps.last == .extras)
        #expect(last.forwardButtonTitle == OnboardingFlow.finishTitle)
    }

    @Test("The dots count the steps this machine walks, not the template")
    func progress() {
        let everything = OnboardingFlow(step: .agent, offersAgentChoice: true, offersExtras: true)
        #expect(everything.progress == OnboardingProgress(position: 3, count: 4))

        let lean = OnboardingFlow(step: .checks)
        #expect(lean.progress == OnboardingProgress(position: 2, count: 2))

        let withExtrasAlone = OnboardingFlow(step: .extras, offersExtras: true)
        #expect(withExtrasAlone.progress == OnboardingProgress(position: 3, count: 3))
        #expect(withExtrasAlone.progress.accessibilityLabel == "Step 3 of 3")
    }

    @Test("Back is on every step and inactive on the first alone")
    func back() {
        let steps: [OnboardingStep] = [.greeting, .checks, .agent, .extras]
        for step in steps {
            let flow = OnboardingFlow(step: step, offersAgentChoice: true, offersExtras: true)
            #expect(flow.backButtonTitle == OnboardingFlow.backTitle)
            #expect(flow.canGoBack == (step != .greeting))
        }
    }

    @Test("Back is offered even when the window opened straight onto the checks")
    func backFromAReturningOpen() {
        var flow = OnboardingFlow(step: OnboardingFlow.firstStep(trigger: .none))
        #expect(flow.step == .checks)
        #expect(flow.canGoBack)
        let wentBack = flow.goBack()
        #expect(wentBack)
        #expect(flow.step == .greeting)
    }
}

@Suite("What the welcome window records")
struct OnboardingCompletionTests {
    @Test("a blocked machine may leave, and leaving is never a completion")
    func blockedNeverCompletes() {
        #expect(!OnboardingGate.completes(verdict: .blocked))
    }

    @Test("an assistant whose checks never settled has not been completed")
    func checkingNeverCompletes() {
        #expect(SetupReport.pending.verdict == .checking)
        #expect(!OnboardingGate.completes(verdict: .checking))
    }

    @Test("a settled machine records the completion")
    func settledCompletes() {
        for verdict in [SetupVerdict.ready, .readyWithNotes] {
            #expect(OnboardingGate.completes(verdict: verdict))
        }
        #expect(OnboardingGate.completes(verdict: nil))
    }
}

@Suite("The welcome window while the checks are still running")
struct OnboardingUnsettledTests {
    @Test("no step is the last one while this machine's offers are unknown")
    func neverLastWhileUnknown() {
        let flow = OnboardingFlow(step: .checks, offersAreKnown: false)
        #expect(flow.next == nil)
        #expect(!flow.isLastStep)
        #expect(!flow.canGoForward)
        #expect(flow.forwardButtonTitle == OnboardingFlow.forwardTitle)
    }

    @Test("the button says what ends setup only once the offers are known")
    func lastOnceKnown() {
        var flow = OnboardingFlow(step: .checks, offersAreKnown: false)
        #expect(flow.forwardButtonTitle == OnboardingFlow.forwardTitle)
        flow.settleOffers(true)
        #expect(flow.isLastStep)
        #expect(flow.canGoForward)
        #expect(flow.forwardButtonTitle == OnboardingFlow.finishTitle)
    }

    @Test("the greeting walks on, because the checks always follow it")
    func forwardStaysOpenWhereTheNextStepIsCertain() {
        let flow = OnboardingFlow(step: .greeting, offersAreKnown: false)
        #expect(flow.next == .checks)
        #expect(flow.canGoForward)
        #expect(flow.forwardButtonTitle == OnboardingFlow.startTitle)
    }

    @Test("a laptop cannot walk past the checks before it knows about the agent choice")
    func forwardWaitsWhereAnOptionalStepCouldArrive() {
        let laptop = OnboardingFlow(step: .checks, offersExtras: true, offersAreKnown: false)
        #expect(laptop.next == .extras)
        #expect(!laptop.canGoForward)

        var settled = laptop
        settled.offerAgentChoice(true)
        settled.settleOffers(true)
        #expect(settled.next == .agent)
        #expect(settled.canGoForward)
    }

    @Test("the agent step waits too, because the extras sit after it")
    func forwardWaitsOnTheAgentStep() {
        let flow = OnboardingFlow(step: .agent, offersAgentChoice: true, offersAreKnown: false)
        #expect(!flow.canGoForward)
    }

    @Test("an offer that arrives late lengthens the walk under the reader")
    func lateOffer() {
        var flow = OnboardingFlow(step: .extras, offersExtras: true, offersAreKnown: false)
        #expect(flow.steps == [.greeting, .checks, .extras])
        flow.offerAgentChoice(true)
        flow.settleOffers(true)
        #expect(flow.steps == [.greeting, .checks, .agent, .extras])
        #expect(flow.back == .agent)
        #expect(flow.progress == OnboardingProgress(position: 4, count: 4))
    }

    @Test("a withdrawn offer leaves the walk once the reader has stepped off it")
    func withdrawnOfferLeavesOnceAbandoned() {
        var flow = OnboardingFlow(step: .agent, offersAgentChoice: true, offersExtras: true)
        flow.offerAgentChoice(false)
        #expect(flow.steps == [.greeting, .checks, .agent, .extras])
        let wentBack = flow.goBack()
        #expect(wentBack)
        #expect(flow.step == .checks)
        #expect(flow.steps == [.greeting, .checks, .extras])
        #expect(flow.next == .extras)
        #expect(flow.progress == OnboardingProgress(position: 2, count: 3))
    }
}
