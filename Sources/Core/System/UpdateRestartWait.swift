import Foundation

public struct UpdateRestartWait: Sendable, Equatable {
    public static let limit = 20

    private var waited = 0

    public init() {}

    public mutating func tick(seconds: Int, isAsking: Bool) -> Bool {
        if !isAsking { waited += seconds }
        return waited >= Self.limit
    }
}
