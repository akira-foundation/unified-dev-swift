import Testing
import Foundation
@testable import Core

@Suite("Onboarding flow")
struct OnboardingFlowTests {
    @Test("A greeting and the checks, and nothing else")
    func order() {
        #expect(OnboardingStep.order == [.greeting, .checks])
        #expect(OnboardingFlow(step: .greeting).steps == [.greeting, .checks])
        #expect(OnboardingFlow(step: .greeting).next == .checks)
        #expect(OnboardingFlow(step: .checks).next == nil)
    }

    @Test("Back exists from the checks and nowhere else")
    func back() {
        let greeting = OnboardingFlow(step: .greeting)
        #expect(greeting.back == nil)
        #expect(!greeting.canGoBack)
        #expect(greeting.backButtonTitle == nil)

        let checks = OnboardingFlow(step: .checks)
        #expect(checks.back == .greeting)
        #expect(checks.canGoBack)
        #expect(checks.backButtonTitle != nil)
    }

    @Test("Two screens means one button that starts and one that leaves")
    func titles() {
        #expect(OnboardingFlow.startTitle == "Get started")
        #expect(
            OnboardingPrimary(step: .checks, verdict: .ready).title
                == OnboardingPrimary.finishTitle
        )
    }

    @Test("A first run opens on the greeting, and every other reason opens on the checks")
    func opening() {
        #expect(OnboardingFlow.firstStep(trigger: .firstRun) == .greeting)
        #expect(OnboardingFlow.firstStep(trigger: .blocked) == .checks)
        #expect(OnboardingFlow.firstStep(trigger: .none) == .checks)
    }

    @Test("Advancing walks the whole sequence and then refuses")
    func advancing() {
        var flow = OnboardingFlow(step: .greeting)
        let moved = flow.advance()
        #expect(moved)
        #expect(flow.step == .checks)
        let refused = flow.advance()
        #expect(!refused)
        #expect(flow.step == .checks)
    }

    @Test("Going back walks to the greeting and then refuses")
    func goingBack() {
        var flow = OnboardingFlow(step: .checks)
        #expect(flow.canGoBack)
        let wentBack = flow.goBack()
        #expect(wentBack)
        #expect(flow.step == .greeting)
        #expect(!flow.canGoBack)
        let wentBackAgain = flow.goBack()
        #expect(!wentBackAgain)
        #expect(flow.step == .greeting)
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
        let primary = OnboardingPrimary(step: .greeting, verdict: .blocked)
        #expect(primary.action == .finish)
        #expect(primary.title == OnboardingPrimary.finishTitle)
    }
}
