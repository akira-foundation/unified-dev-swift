import Foundation

public enum OnboardingStep: String, Sendable, Hashable, CaseIterable, Identifiable {
    case greeting
    case checks
    case agent
    case extras

    public var id: String { rawValue }

    public static let order: [OnboardingStep] = [.greeting, .checks, .agent, .extras]

    public var isOptional: Bool {
        switch self {
        case .greeting, .checks: false
        case .agent, .extras: true
        }
    }
}

public struct OnboardingFlow: Sendable, Hashable {
    public private(set) var step: OnboardingStep
    public private(set) var offersAgentChoice: Bool
    public private(set) var offersExtras: Bool
    public private(set) var offersAreKnown: Bool

    public init(
        step: OnboardingStep = .greeting,
        offersAgentChoice: Bool = false,
        offersExtras: Bool = false,
        offersAreKnown: Bool = true
    ) {
        self.step = step
        self.offersAgentChoice = offersAgentChoice
        self.offersExtras = offersExtras
        self.offersAreKnown = offersAreKnown
    }

    public static func firstStep(trigger: OnboardingTrigger) -> OnboardingStep {
        switch trigger {
        case .firstRun: .greeting
        case .blocked, .none: .checks
        }
    }

    public var steps: [OnboardingStep] {
        OnboardingStep.order.filter { !$0.isOptional || isOffered($0) || $0 == step }
    }

    public func isOffered(_ step: OnboardingStep) -> Bool {
        switch step {
        case .agent: offersAgentChoice
        case .extras: offersExtras
        case .greeting, .checks: true
        }
    }

    public mutating func offerAgentChoice(_ isOffered: Bool) {
        offersAgentChoice = isOffered
    }

    public mutating func offerExtras(_ isOffered: Bool) {
        offersExtras = isOffered
    }

    public mutating func settleOffers(_ areKnown: Bool) {
        offersAreKnown = areKnown
    }

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

    public var isLastStep: Bool { next == nil && offersAreKnown }

    public var canGoForward: Bool {
        if offersAreKnown { return true }
        return nextInTemplateIsCertain
    }

    private var nextInTemplateIsCertain: Bool {
        guard let index = OnboardingStep.order.firstIndex(of: step),
              index + 1 < OnboardingStep.order.count else { return false }
        return !OnboardingStep.order[index + 1].isOptional
    }

    public static let forwardTitle = "Continue"
    public static let startTitle = "Get started"
    public static let backTitle = "Back"
    public static let finishTitle = "Start using Unified Dev"
    public static let checkAgainTitle = "Check again"

    public var forwardButtonTitle: String {
        if isLastStep { return Self.finishTitle }
        return step == .greeting ? Self.startTitle : Self.forwardTitle
    }

    public var progress: OnboardingProgress {
        OnboardingProgress(position: position + 1, count: steps.count)
    }

    public var backButtonTitle: String { Self.backTitle }

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

public struct OnboardingProgress: Sendable, Hashable {
    public let position: Int
    public let count: Int

    public init(position: Int, count: Int) {
        self.position = position
        self.count = count
    }

    public var accessibilityLabel: String { "Step \(position) of \(count)" }
}
