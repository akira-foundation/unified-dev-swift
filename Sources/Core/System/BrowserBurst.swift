import Foundation

public struct BrowserNotice: Sendable, Equatable {
    public var title: String
    public var message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public struct BrowserBurst: Sendable, Equatable {
    public enum Verdict: Sendable, Equatable {
        case allowed
        case refused
        case refusedAndUnsaid
    }

    public let limit: Int
    public let window: TimeInterval

    private var moments: [Date] = []
    private var hasSaidSo = false

    public init(limit: Int, window: TimeInterval) {
        self.limit = limit
        self.window = window
    }

    public mutating func take(at now: Date) -> Verdict {
        moments.removeAll { now.timeIntervalSince($0) >= window }
        guard moments.count < limit else {
            guard !hasSaidSo else { return .refused }
            hasSaidSo = true
            return .refusedAndUnsaid
        }
        moments.append(now)
        hasSaidSo = false
        return .allowed
    }
}
