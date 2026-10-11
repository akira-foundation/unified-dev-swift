import Foundation

public struct SpendCost: Sendable, Hashable, Codable {
    public var freshInput: Double
    public var cacheRead: Double
    public var cacheWrite: Double
    public var output: Double
    public var saved: Double

    public init(
        freshInput: Double = 0,
        cacheRead: Double = 0,
        cacheWrite: Double = 0,
        output: Double = 0,
        saved: Double = 0
    ) {
        self.freshInput = freshInput
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.output = output
        self.saved = saved
    }

    public static let none = SpendCost()

    public var total: Double { freshInput + cacheRead + cacheWrite + output }

    public static func + (left: SpendCost, right: SpendCost) -> SpendCost {
        SpendCost(
            freshInput: left.freshInput + right.freshInput,
            cacheRead: left.cacheRead + right.cacheRead,
            cacheWrite: left.cacheWrite + right.cacheWrite,
            output: left.output + right.output,
            saved: left.saved + right.saved
        )
    }
}

public struct Spend: Sendable, Hashable, Codable {
    public var usage: TokenUsage
    public var cost: SpendCost
    public var unpriced: TokenUsage

    public init(usage: TokenUsage = .none, cost: SpendCost = .none, unpriced: TokenUsage = .none) {
        self.usage = usage
        self.cost = cost
        self.unpriced = unpriced
    }

    public static let none = Spend()

    public var isEmpty: Bool { usage.isEmpty }

    public var hasUnpricedTokens: Bool { !unpriced.isEmpty }

    public static func + (left: Spend, right: Spend) -> Spend {
        Spend(
            usage: left.usage + right.usage,
            cost: left.cost + right.cost,
            unpriced: left.unpriced + right.unpriced
        )
    }

    public static func += (left: inout Spend, right: Spend) {
        left = left + right
    }

    public static func sum(_ spends: some Sequence<Spend>) -> Spend {
        spends.reduce(.none, +)
    }
}
