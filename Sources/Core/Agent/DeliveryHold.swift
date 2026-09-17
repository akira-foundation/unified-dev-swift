import Foundation

public enum DeliveryHold: Equatable, Sendable, CaseIterable {
    case setup
    case question
    case turn
    case none

    public static func of(
        isRunningSetup: Bool,
        isTurnRunning: Bool,
        isAwaitingQuestion: Bool
    ) -> DeliveryHold {
        if isRunningSetup { return .setup }
        if isAwaitingQuestion { return .question }
        if isTurnRunning { return .turn }
        return .none
    }

    public func allowsDelivery(on agent: AgentKind) -> Bool {
        switch self {
        case .none: true
        case .turn: agent.acceptsMidTurnMessage
        case .setup, .question: false
        }
    }

    public func sentence(on agent: AgentKind) -> String? {
        guard !allowsDelivery(on: agent) else { return nil }
        switch self {
        case .setup: return "Goes as soon as setup finishes."
        case .question: return "Goes once you have answered the question above."
        case .turn: return "Goes when this turn ends."
        case .none: return nil
        }
    }
}
