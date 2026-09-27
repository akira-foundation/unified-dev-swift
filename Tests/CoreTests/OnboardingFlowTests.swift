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
        #expect(flow.forwardButtonTitle == OnboardingFlow.forwardTitle)

        let checks = OnboardingFlow(step: .checks)
        #expect(checks.next == nil)
        #expect(checks.isLastStep)
        #expect(checks.forwardButtonTitle == OnboardingPrimary.finishTitle)
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
        #expect(agent.forwardButtonTitle == OnboardingPrimary.finishTitle)
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
        #expect(extras.forwardButtonTitle == OnboardingPrimary.finishTitle)
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

    @Test("Only the last step's button says what ends setup")
    func forwardTitles() {
        #expect(OnboardingFlow.forwardTitle == "Continue")
        for step in [OnboardingStep.greeting, .checks, .agent] {
            let standing = OnboardingFlow(step: step, offersAgentChoice: true, offersExtras: true)
            #expect(!standing.isLastStep)
            #expect(standing.forwardButtonTitle == OnboardingFlow.forwardTitle)
        }
        let last = OnboardingFlow(step: .extras, offersAgentChoice: true, offersExtras: true)
        #expect(last.isLastStep)
        #expect(last.steps.last == .extras)
        #expect(last.forwardButtonTitle == OnboardingPrimary.finishTitle)
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

@Suite("The welcome window's primary button")
struct OnboardingPrimaryTests {
    @Test("A blocked machine is offered another look rather than a closed door")
    func blocked() {
        let primary = OnboardingPrimary(step: .checks, verdict: .blocked)
        #expect(primary.action == .checkAgain)
        #expect(primary.title == "Check again")
    }

    @Test("The checks let somebody leave, whatever the verdict is doing behind it")
    func finishing() {
        for verdict in [SetupVerdict.checking, .ready, .readyWithNotes] {
            let primary = OnboardingPrimary(step: .checks, verdict: verdict)
            #expect(primary.action == .finish)
            #expect(primary.title == OnboardingPrimary.finishTitle)
        }
    }

    @Test("Only the checks' own button turns into a re-check when the verdict is no")
    func blockedOffTheChecks() {
        for step in [OnboardingStep.greeting, .agent, .extras] {
            let primary = OnboardingPrimary(step: step, verdict: .blocked)
            #expect(primary.action == .finish)
            #expect(primary.title == OnboardingPrimary.finishTitle)
        }
    }
}
