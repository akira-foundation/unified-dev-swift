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

    @Test("The greeting's own button and the footer never disagree")
    func titlesAgree() {
        #expect(OnboardingFlow.title(leaving: .greeting) == OnboardingFlow.startTitle)
        #expect(OnboardingFlow.title(leaving: .checks) == OnboardingFlow.forwardTitle)
        let toChecks = OnboardingPrimary(step: .greeting, verdict: .ready, next: .checks)
        #expect(toChecks.title == OnboardingFlow.title(leaving: .greeting))
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
        var flow = OnboardingFlow.opening(trigger: .none)
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
        let primary = OnboardingPrimary(step: .checks, verdict: .blocked, next: nil)
        #expect(primary.action == .checkAgain)
        #expect(primary.title == "Check again")
    }

    @Test("A step with somewhere to go goes there")
    func advancing() {
        let toChecks = OnboardingPrimary(step: .greeting, verdict: .checking, next: .checks)
        #expect(toChecks.action == .advance(.checks))
        #expect(toChecks.title == "Get started")
    }

    @Test("The last step's button leaves, whatever the verdict is doing behind it")
    func finishing() {
        for verdict in [SetupVerdict.checking, .ready, .readyWithNotes] {
            let primary = OnboardingPrimary(step: .checks, verdict: verdict, next: nil)
            #expect(primary.action == .finish)
            #expect(primary.title == OnboardingPrimary.finishTitle)
        }
    }

    @Test("The greeting leads on even while the checks are still saying no")
    func blockedOnTheGreeting() {
        let primary = OnboardingPrimary(step: .greeting, verdict: .blocked, next: .checks)
        #expect(primary.action == .advance(.checks))
        #expect(primary.title == OnboardingFlow.startTitle)
    }
}
