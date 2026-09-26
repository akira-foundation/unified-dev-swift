import Foundation

public enum OnboardingStep: String, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    case greeting
    case checks

    public var id: String { rawValue }

    public static let order: [OnboardingStep] = [.greeting, .checks]
}

public struct OnboardingFlow: Sendable, Hashable {
    public private(set) var step: OnboardingStep

    public init(step: OnboardingStep = .greeting) {
        self.step = step
    }

    public static func firstStep(trigger: OnboardingTrigger) -> OnboardingStep {
        switch trigger {
        case .firstRun: .greeting
        case .blocked, .none: .checks
        }
    }

    public static func opening(trigger: OnboardingTrigger) -> OnboardingFlow {
        OnboardingFlow(step: firstStep(trigger: trigger))
    }

    public var steps: [OnboardingStep] { OnboardingStep.order }

    private var position: Int { steps.firstIndex(of: step) ?? 0 }

    public var next: OnboardingStep? {
        let walked = steps
        let after = position + 1
        return after < walked.count ? walked[after] : nil
    }

    public var back: OnboardingStep? {
        let before = position - 1
        return before >= 0 ? steps[before] : nil
    }

    public var canGoBack: Bool { back != nil }

    public static let forwardTitle = "Continue"
    public static let startTitle = "Get started"

    public static func title(leaving step: OnboardingStep) -> String {
        step == .greeting ? startTitle : forwardTitle
    }

    public var backButtonTitle: String? { canGoBack ? "Back" : nil }

    @discardableResult
    public mutating func advance() -> Bool {
        guard let next else { return false }
        step = next
        return true
    }

    @discardableResult
    public mutating func goBack() -> Bool {
        guard let back else { return false }
        step = back
        return true
    }
}

public struct OnboardingPrimary: Sendable, Hashable {
    public enum Action: Sendable, Hashable {
        case checkAgain
        case advance(OnboardingStep)
        case finish
    }

    public let action: Action
    public let title: String

    public static let finishTitle = "Start using Unified Dev"

    public init(step: OnboardingStep, verdict: SetupVerdict, next: OnboardingStep?) {
        let resolved = Self.resolve(step: step, verdict: verdict, next: next)
        self.action = resolved.action
        self.title = resolved.title
    }

    private static func resolve(
        step: OnboardingStep,
        verdict: SetupVerdict,
        next: OnboardingStep?
    ) -> (action: Action, title: String) {
        if step == .checks, verdict == .blocked {
            return (.checkAgain, verdict.primaryButtonTitle)
        }
        guard let next else { return (.finish, finishTitle) }
        return (.advance(next), OnboardingFlow.title(leaving: step))
    }
}
