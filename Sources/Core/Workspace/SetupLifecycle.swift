import Foundation

public enum SetupEvent: Sendable, Hashable {
    case runStarted
    case runFinished(succeeded: Bool, log: String)
    case runSkipped(note: String?)
    case runInterrupted
    case worktreeRebuilt(hasSetupScript: Bool)

    public var note: String? {
        switch self {
        case .runStarted:
            nil
        case .runFinished:
            nil
        case .runSkipped(let note):
            note
        case .runInterrupted:
            "[unifieddev] The app stopped while the setup script was running, so this run was "
                + "interrupted before it could report a result. Run setup again to finish it."
        case .worktreeRebuilt:
            "[unifieddev] This worktree was rebuilt when the workspace was restored, so anything the "
                + "setup script installed is gone. Run setup again."
        }
    }

    var noteReplacesLog: Bool {
        if case .runSkipped = self { return true }
        return false
    }
}

public extension SetupState {
    func transition(on event: SetupEvent) -> StateTransition<SetupState> {
        switch event {
        case .runStarted:
            return self == .running ? .unchanged : .moves(to: .running)

        case .runFinished(let succeeded, _):
            guard self == .running else { return .refused }
            return .moves(to: succeeded ? .succeeded : .failed)

        case .runSkipped:
            if self == .running { return .refused }
            return self == .skipped ? .unchanged : .moves(to: .skipped)

        case .runInterrupted:
            guard self == .running else { return .refused }
            return .moves(to: .pending)

        case .worktreeRebuilt(let hasSetupScript):
            let destination: SetupState = hasSetupScript ? .pending : .skipped
            return self == destination ? .unchanged : .moves(to: destination)
        }
    }
}

public extension Workspace {
    @discardableResult
    mutating func apply(_ event: SetupEvent) -> StateTransition<SetupState> {
        let outcome = setupState.transition(on: event)

        switch outcome {
        case .refused:
            RefusedTransitions.record(
                machine: "setup", from: setupState.rawValue, event: event.name
            )
            return outcome

        case .unchanged:
            return outcome

        case .moves(let next):
            setupState = next
        }

        if case .runFinished(_, let log) = event {
            setupLog = Self.capped(log)
        } else if let note = event.note {
            setupLog = event.noteReplacesLog || setupLog.isEmpty
                ? note
                : Self.capped(setupLog + "\n" + note)
        }

        return outcome
    }

    private static func capped(_ log: String) -> String {
        log.count > setupLogLimit ? String(log.suffix(setupLogLimit)) : log
    }

    static let setupLogLimit = 200_000
}

extension SetupEvent {
    var name: String {
        switch self {
        case .runStarted: "runStarted"
        case .runFinished(let succeeded, _): succeeded ? "runFinished(succeeded)" : "runFinished(failed)"
        case .runSkipped: "runSkipped"
        case .runInterrupted: "runInterrupted"
        case .worktreeRebuilt(let hasSetupScript): "worktreeRebuilt(hasSetupScript: \(hasSetupScript))"
        }
    }
}
