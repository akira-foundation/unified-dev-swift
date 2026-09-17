import Foundation
import Synchronization

final class CodexTurnHandle: Sendable {
    struct Stopped: Sendable {
        let generation: UInt64
        let turnID: String?
    }

    private struct State {
        var current: String?
        var lastTurnID: String?
        var cancelled = false
        var generation: UInt64 = 0
        var replacement: UUID?
        var intent = UUID()
    }

    private let state = Mutex(State())

    var turnID: String? { state.withLock(\.current) }

    var steerableTurnID: String? {
        state.withLock { $0.cancelled ? nil : $0.current }
    }

    var wasCancelled: Bool { state.withLock(\.cancelled) }
    var generation: UInt64 { state.withLock(\.generation) }
    var intent: UUID { state.withLock(\.intent) }

    func prepareReplacement() -> UUID? {
        state.withLock {
            guard $0.cancelled || $0.current == nil else { return nil }
            let token = UUID()
            $0.replacement = token
            $0.intent = token
            return token
        }
    }

    func finishReplacement(_ token: UUID?) {
        state.withLock {
            if $0.replacement == token { $0.replacement = nil }
        }
    }

    func acceptsTerminal(turnID: String, intent: UUID? = nil) -> Bool {
        state.withLock {
            if let intent, intent != $0.intent { return false }
            if $0.replacement != nil, $0.lastTurnID == turnID { return false }
            return $0.current == nil || $0.current == turnID
        }
    }

    func check(_ generation: UInt64) throws {
        guard state.withLock({ $0.generation == generation }) else { throw CancellationError() }
        try Task.checkCancellation()
    }

    func begin(turnID: String, generation: UInt64) -> Bool {
        state.withLock { state in
            guard state.generation == generation else { return false }
            state.current = turnID
            state.lastTurnID = turnID
            state.cancelled = false
            state.replacement = nil
            return true
        }
    }

    @discardableResult
    func markCancelled() -> Stopped {
        state.withLock {
            $0.generation &+= 1
            $0.cancelled = true
            return Stopped(generation: $0.generation, turnID: $0.current)
        }
    }

    func end() {
        state.withLock { $0.current = nil }
    }
}
