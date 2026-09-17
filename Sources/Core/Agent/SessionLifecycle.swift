import Foundation

public enum SessionEvent: Sendable, Hashable {
    case turnStarted
    case blocked
    case unblocked
    case turnFinished(isError: Bool)
    case cancelled
    case processExited
    case processFailed
    case appRelaunched
}

public extension SessionState {
    var isMidTurn: Bool { self == .running || self == .waiting }

    func transition(on event: SessionEvent) -> StateTransition<SessionState> {
        switch event {
        case .turnStarted:
            switch self {
            case .running: return .unchanged
            case .waiting: return .refused
            case .idle, .failed, .cancelled: return .moves(to: .running)
            }

        case .blocked:
            switch self {
            case .running: return .moves(to: .waiting)
            case .waiting: return .unchanged
            case .idle, .failed, .cancelled: return .refused
            }

        case .unblocked:
            return self == .waiting ? .moves(to: .running) : .unchanged

        case .turnFinished(let isError):
            guard isMidTurn else { return .unchanged }
            return .moves(to: isError ? .failed : .idle)

        case .cancelled:
            switch self {
            case .running, .waiting: return .moves(to: .cancelled)
            case .cancelled: return .unchanged
            case .idle, .failed: return .refused
            }

        case .processExited:
            return isMidTurn ? .moves(to: .idle) : .unchanged

        case .processFailed:
            return isMidTurn ? .moves(to: .failed) : .unchanged

        case .appRelaunched:
            return isMidTurn ? .moves(to: .idle) : .unchanged
        }
    }
}

public extension Session {
    mutating func applyInteractiveState(_ observed: SessionState, at date: Date = Date()) {
        guard state != observed else { return }
        if !state.isMidTurn { apply(.turnStarted, at: date) }
        switch observed {
        case .running:
            if state == .waiting { apply(.unblocked, at: date) }
        case .waiting:
            apply(.blocked, at: date)
        case .idle:
            apply(.turnFinished(isError: false), at: date)
        case .failed:
            apply(.turnFinished(isError: true), at: date)
        case .cancelled:
            apply(.cancelled, at: date)
        }
    }

    @discardableResult
    mutating func apply(_ event: SessionEvent, at date: Date = Date()) -> StateTransition<SessionState> {
        let outcome = state.transition(on: event)
        switch outcome {
        case .refused:
            RefusedTransitions.record(machine: "session", from: state.rawValue, event: event.name)
        case .unchanged:
            break
        case .moves(let next):
            state = next
            updatedAt = date
        }
        return outcome
    }
}

extension SessionEvent {
    var name: String {
        switch self {
        case .turnStarted: "turnStarted"
        case .blocked: "blocked"
        case .unblocked: "unblocked"
        case .turnFinished(let isError): isError ? "turnFinished(error)" : "turnFinished"
        case .cancelled: "cancelled"
        case .processExited: "processExited"
        case .processFailed: "processFailed"
        case .appRelaunched: "appRelaunched"
        }
    }
}
