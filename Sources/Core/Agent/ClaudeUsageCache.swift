import Foundation

public enum ClaudeUsageCache {
    public static let key = "cachedUsageUtilization"

    public static let trusted: TimeInterval = 3600

    public struct Reading: Sendable, Equatable {
        public var payload: Data
        public var fetchedAt: Date

        public init(payload: Data, fetchedAt: Date) {
            self.payload = payload
            self.fetchedAt = fetchedAt
        }
    }

    public static func fetchedAt(in accountJSON: Data?, at now: Date) -> Date? {
        guard let cached = cached(in: accountJSON),
              let milliseconds = cached["fetchedAtMs"]?.doubleValue,
              let stamp = stamp(milliseconds, at: now)
        else { return nil }
        return stamp
    }

    static func stamp(_ milliseconds: Double, at now: Date) -> Date? {
        guard milliseconds.isFinite, milliseconds >= 0 else { return nil }
        let stamp = Date(timeIntervalSince1970: milliseconds / 1000)
        guard stamp.timeIntervalSince(now) <= grace else { return nil }
        return stamp
    }

    public static let grace: TimeInterval = 5

    public static func isTrusted(fetchedAt: Date, at now: Date) -> Bool {
        (-grace...trusted).contains(now.timeIntervalSince(fetchedAt))
    }

    public static func reading(from accountJSON: Data?, at now: Date) -> Reading? {
        guard let cached = cached(in: accountJSON),
              let milliseconds = cached["fetchedAtMs"]?.doubleValue,
              let fetchedAt = stamp(milliseconds, at: now),
              let limits = cached["utilization"]?.objectValue,
              isTrusted(fetchedAt: fetchedAt, at: now)
        else { return nil }

        let envelope = JSONValue.object([
            "rate_limits_available": .bool(true),
            "rate_limits": .object(limits),
            observedKey: .number(milliseconds),
        ])
        guard let payload = try? JSONEncoder().encode(envelope) else { return nil }
        return Reading(payload: payload, fetchedAt: fetchedAt)
    }

    static let observedKey = "observed_at_ms"

    static func cached(in accountJSON: Data?) -> JSONValue? {
        guard let accountJSON, let root = JSONValue.parse(accountJSON) else { return nil }
        return root[key]
    }
}
