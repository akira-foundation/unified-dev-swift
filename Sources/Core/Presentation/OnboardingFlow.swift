import Foundation

public enum OnboardingStep: String, Sendable, Hashable, CaseIterable, Identifiable, Codable {
    case greeting
    case checks
    case keepAwake
    case commandLine
    case promptSubmission

    public var id: String { rawValue }

    public static let order: [OnboardingStep] = [
        .greeting, .checks, .keepAwake, .commandLine, .promptSubmission,
    ]

    public var isOptional: Bool { self == .commandLine || self == .keepAwake }

    public var arrivalButtonTitle: String? {
        switch self {
        case .greeting: nil
        case .checks: "See what Unified Dev needs"
        case .keepAwake: "Keep this Mac awake"
        case .commandLine: "Use Unified Dev from your terminal"
        case .promptSubmission: "Say what Unified Dev does next"
        }
    }
}

public struct OnboardingFlow: Sendable, Hashable {
    public private(set) var step: OnboardingStep
    public private(set) var history: [OnboardingStep]
    public private(set) var offersCommandLine: Bool
    public private(set) var offersKeepAwake: Bool

    public init(
        step: OnboardingStep = .greeting,
        offersCommandLine: Bool = false,
        offersKeepAwake: Bool = false
    ) {
        self.step = step
        self.history = [step]
        self.offersCommandLine = offersCommandLine
        self.offersKeepAwake = offersKeepAwake
    }

    public static func firstStep(trigger: OnboardingTrigger) -> OnboardingStep {
        switch trigger {
        case .firstRun: .greeting
        case .blocked, .none: .checks
        }
    }

    public static func opening(
        trigger: OnboardingTrigger,
        offersCommandLine: Bool = false,
        offersKeepAwake: Bool = false
    ) -> OnboardingFlow {
        OnboardingFlow(
            step: firstStep(trigger: trigger),
            offersCommandLine: offersCommandLine,
            offersKeepAwake: offersKeepAwake
        )
    }

    public var steps: [OnboardingStep] {
        OnboardingStep.order.filter { !$0.isOptional || isOffered($0) || $0 == step }
    }

    public func isOffered(_ step: OnboardingStep) -> Bool {
        switch step {
        case .commandLine: offersCommandLine
        case .keepAwake: offersKeepAwake
        default: true
        }
    }

    public mutating func offerCommandLine(_ isOffered: Bool) {
        offersCommandLine = isOffered
    }

    public mutating func offerKeepAwake(_ isOffered: Bool) {
        offersKeepAwake = isOffered
    }

    private var position: Int { steps.firstIndex(of: step) ?? 0 }

    public var next: OnboardingStep? {
        let walked = steps
        let after = (walked.firstIndex(of: step) ?? 0) + 1
        return after < walked.count ? walked[after] : nil
    }

    public var back: OnboardingStep? {
        let before = position - 1
        return before >= 0 ? steps[before] : nil
    }

    public var canGoBack: Bool { back != nil }

    public var forwardButtonTitle: String? { next?.arrivalButtonTitle }

    public var backButtonTitle: String? { canGoBack ? "Back" : nil }

    @discardableResult
    public mutating func advance() -> Bool {
        guard let next else { return false }
        step = next
        history.append(next)
        return true
    }

    @discardableResult
    public mutating func goBack() -> Bool {
        guard let back else { return false }
        step = back
        history.append(back)
        return true
    }

    public func isFirstVisit(to step: OnboardingStep) -> Bool {
        history.filter { $0 == step }.count <= 1
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
        if step == .checks, verdict == .blocked {
            self.action = .checkAgain
            self.title = verdict.primaryButtonTitle
        } else if let next, let forward = next.arrivalButtonTitle {
            self.action = .advance(next)
            self.title = forward
        } else {
            self.action = .finish
            self.title = Self.finishTitle
        }
    }
}
