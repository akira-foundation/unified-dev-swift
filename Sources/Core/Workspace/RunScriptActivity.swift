import Foundation

public struct RunScriptActivity: Sendable, Hashable {
    public enum State: Sendable, Hashable {
        case idle
        case running(since: Date)
        case stopped(after: Duration?)

        public var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    public static let startGrace: Duration = .seconds(8)

    enum Phase: Sendable, Hashable {
        case idle(busySince: Date?)
        case typed(at: Date)
        case busy(since: Date, idleSince: Date?)
        case stopped(after: Duration?, busySince: Date?)
    }

    private(set) var phase: Phase = .idle(busySince: nil)

    public init() {}

    public var state: State {
        switch phase {
        case .idle: .idle
        case .typed(let at): .running(since: at)
        case .busy(let since, _): .running(since: since)
        case .stopped(let after, _): .stopped(after: after)
        }
    }

    public mutating func typed(at moment: Date) {
        if case .busy(_, nil) = phase { return }
        phase = .typed(at: moment)
    }

    public mutating func observe(busy: Bool, at moment: Date) {
        switch phase {
        case .idle(let busySince):
            guard busy else { return phase = .idle(busySince: nil) }
            phase = busySince.map { .busy(since: $0, idleSince: nil) } ?? .idle(busySince: moment)

        case .typed(let at):
            if busy { return phase = .busy(since: at, idleSince: nil) }
            guard Self.length(from: at, to: moment) >= Self.startGrace else { return }
            phase = .stopped(after: nil, busySince: nil)

        case .busy(let since, let idleSince):
            guard !busy else { return phase = .busy(since: since, idleSince: nil) }
            guard let idleSince else { return phase = .busy(since: since, idleSince: moment) }
            phase = .stopped(after: Self.length(from: since, to: idleSince), busySince: nil)

        case .stopped(let after, let busySince):
            guard busy else { return phase = .stopped(after: after, busySince: nil) }
            phase = busySince.map { .busy(since: $0, idleSince: nil) }
                ?? .stopped(after: after, busySince: moment)
        }
    }

    public mutating func adopt(busy: Bool, at moment: Date) {
        guard busy else { return }
        switch phase {
        case .idle, .stopped: phase = .busy(since: moment, idleSince: nil)
        case .typed, .busy: return
        }
    }

    public mutating func dismiss() {
        guard case .stopped = phase else { return }
        phase = .idle(busySince: nil)
    }

    private static func length(from start: Date, to end: Date) -> Duration {
        .milliseconds(max(0, Int((end.timeIntervalSince(start) * 1000).rounded())))
    }
}
