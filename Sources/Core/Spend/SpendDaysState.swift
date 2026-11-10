import Foundation

public struct SpendDaysState: Sendable, Equatable {
    public enum Standing: Sendable, Equatable {
        case notRead
        case failed
        case kept
        case current

        public var knowsTheFigures: Bool { self == .kept || self == .current }
    }

    public private(set) var days: [SpendDay] = []
    public private(set) var standing = Standing.notRead

    public init() {}

    public mutating func apply(_ read: Result<[SpendDay], any Error>) {
        switch read {
        case .success(let fresh):
            days = fresh
            standing = .current
        case .failure:
            standing = standing.knowsTheFigures ? .kept : .failed
        }
    }

    public static func read(_ store: Store, since day: Date) async -> Result<[SpendDay], any Error> {
        do {
            return .success(try await store.spendDays(since: day))
        } catch {
            return .failure(error)
        }
    }
}
