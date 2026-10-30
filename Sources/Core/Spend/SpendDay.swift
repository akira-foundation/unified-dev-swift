import Foundation

public struct SpendDay: Sendable, Hashable {
    public var provider: AgentKind
    public var day: Date
    public var model: String
    public var directory: String
    public var file: String
    public var usage: TokenUsage
    public var turns: Int
    public var tier: PriceTier

    public init(
        provider: AgentKind,
        day: Date,
        model: String,
        directory: String,
        file: String,
        usage: TokenUsage,
        turns: Int,
        tier: PriceTier
    ) {
        self.provider = provider
        self.day = day
        self.model = model
        self.directory = directory
        self.file = file
        self.usage = usage
        self.turns = turns
        self.tier = tier
    }

    public var spend: Spend {
        ModelPrices.spend(of: usage, model: model, provider: provider, tier: tier)
    }
}
