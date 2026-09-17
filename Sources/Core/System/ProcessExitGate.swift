import Foundation
import Synchronization

final class ProcessExitGate: Sendable {
    private struct State {
        var hasExited = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let state = Mutex(State())

    func signal() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
            state.hasExited = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume()
    }

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let alreadyExited = state.withLock { state -> Bool in
                if state.hasExited { return true }
                state.waiter = continuation
                return false
            }
            if alreadyExited { continuation.resume() }
        }
    }
}
