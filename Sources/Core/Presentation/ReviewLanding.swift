import Foundation

public struct ReviewLanding: Equatable, Sendable {
    public static let retryLimit = 4

    public private(set) var isSettled = false
    private var landed = false
    private var retries = 0

    public init() {}

    public mutating func begin() {
        isSettled = false
        landed = false
        retries = 0
    }

    public mutating func reopen() {
        isSettled = false
        retries = 0
    }

    public mutating func observe(landed: Bool) {
        self.landed = landed
    }

    public mutating func quietPeriodElapsed() -> Bool {
        if landed || retries >= Self.retryLimit {
            isSettled = true
            return false
        }
        retries += 1
        return true
    }
}
