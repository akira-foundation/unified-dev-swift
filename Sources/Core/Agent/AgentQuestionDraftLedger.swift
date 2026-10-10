import Foundation

public struct AgentQuestionDraftLedger: Sendable, Equatable {
    public let limit: Int
    public private(set) var order: [String] = []

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    public mutating func used(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    public mutating func dropping(where isSpare: (String) -> Bool) -> [String] {
        guard order.count > limit else { return [] }

        var dropped: [String] = []

        for key in order {
            guard order.count - dropped.count > limit else { break }
            guard isSpare(key) else { continue }
            dropped.append(key)
        }

        order.removeAll(where: dropped.contains)

        return dropped
    }
}
