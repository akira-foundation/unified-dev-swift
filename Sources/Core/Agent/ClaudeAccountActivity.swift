import Foundation
import Synchronization

public final class ClaudeAccountActivity: Sendable {
    public static let shared = ClaudeAccountActivity()

    private struct State {
        var runs: [AgentAccountID: Int] = [:]
        var probing: Set<AgentAccountID> = []
        var waiting: [AgentAccountID: [CheckedContinuation<Void, Never>]] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    public func beginRun(_ account: AgentAccountID) async -> ClaudeRunLease {
        await withCheckedContinuation { continuation in
            let admitted = state.withLock { state -> Bool in
                guard state.probing.contains(account) else {
                    state.runs[account, default: 0] += 1
                    return true
                }
                state.waiting[account, default: []].append(continuation)
                return false
            }
            if admitted { continuation.resume() }
        }
        return ClaudeRunLease { [self] in endRun(account) }
    }

    public func isRunning(_ account: AgentAccountID) -> Bool {
        state.withLock { ($0.runs[account] ?? 0) > 0 || !($0.waiting[account] ?? []).isEmpty }
    }

    func beginProbe(_ account: AgentAccountID) -> Bool {
        state.withLock { state in
            guard (state.runs[account] ?? 0) == 0,
                  (state.waiting[account] ?? []).isEmpty,
                  !state.probing.contains(account) else { return false }
            state.probing.insert(account)
            return true
        }
    }

    func endProbe(_ account: AgentAccountID) {
        let admitted = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            state.probing.remove(account)
            let waiting = state.waiting.removeValue(forKey: account) ?? []
            if !waiting.isEmpty { state.runs[account, default: 0] += waiting.count }
            return waiting
        }
        for continuation in admitted { continuation.resume() }
    }

    private func endRun(_ account: AgentAccountID) {
        state.withLock { state in
            let remaining = (state.runs[account] ?? 0) - 1
            state.runs[account] = remaining > 0 ? remaining : nil
        }
    }
}

public final class ClaudeRunLease: Sendable {
    private let release: Mutex<(@Sendable () -> Void)?>

    init(release: @escaping @Sendable () -> Void) {
        self.release = Mutex(release)
    }

    public func end() {
        let pending = release.withLock { held -> (@Sendable () -> Void)? in
            defer { held = nil }
            return held
        }
        pending?()
    }

    deinit { end() }
}
