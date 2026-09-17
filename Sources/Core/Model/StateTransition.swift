import Foundation

public enum StateTransition<State: Sendable & Equatable>: Sendable, Equatable {
    case moves(to: State)
    case unchanged
    case refused

    public var moves: Bool {
        if case .moves = self { return true }
        return false
    }

    public var destination: State? {
        if case .moves(let state) = self { return state }
        return nil
    }

    public var isRefused: Bool { self == .refused }
}
