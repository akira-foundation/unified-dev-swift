import Foundation

public actor SharedReading<Value: Sendable> {
    private let read: @Sendable () async -> Value?
    private let now: @Sendable () -> ContinuousClock.Instant
    private var last: (value: Value, at: ContinuousClock.Instant)?
    private var inFlight: Task<Value?, Never>?

    public init(
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now },
        read: @escaping @Sendable () async -> Value?
    ) {
        self.now = now
        self.read = read
    }

    public func value(notOlderThan maxAge: Duration) async -> Value? {
        if let last, now() - last.at < maxAge { return last.value }
        if let inFlight { return await inFlight.value }
        let startedAt = now()
        let reading = Task { await read() }
        inFlight = reading
        let value = await reading.value
        inFlight = nil
        if let value { last = (value, startedAt) }
        return value
    }
}
