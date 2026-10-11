import Foundation

public enum SpendLines {
    public static let title = "What the agents cost"
    public static let shortTitle = "Agent spend"
    public static let openScreen = "Open the spend screen"
    public static let keepsNoUsage = "keeps no usage on disk"
    public static let notRead = "not read yet"
    public static let nothingYet = "nothing in this window"

    public static func providerLine(_ provider: SpendBoard.ProviderLine) -> String {
        switch provider.reading {
        case .keepsNoUsage:
            keepsNoUsage
        case .notRead:
            notRead
        case .stillReading(let pending):
            stillReading(pending)
        case .measured:
            spendLine(provider.spend)
        }
    }

    public static let noPublishedPrice = "no published price"

    public static func spendLine(_ spend: Spend) -> String {
        guard !spend.isEmpty else { return nothingYet }
        let tokens = SpendFormat.tokens(spend.usage.total) + " tokens, "
        guard spend.usage != spend.unpriced else { return tokens + noPublishedPrice }
        return tokens + SpendFormat.money(spend.cost.total)
    }

    public static func stillReading(_ pending: Int) -> String {
        pending == 1 ? "still reading 1 transcript" : "still reading \(pending) transcripts"
    }

    public static func turns(_ count: Int) -> String {
        count == 1 ? "1 turn" : "\(count) turns"
    }

    public static func sessions(_ count: Int) -> String {
        count == 1 ? "1 chat" : "\(count) chats"
    }

    public static func savedLine(_ cost: SpendCost) -> String {
        "The cache saved " + SpendFormat.money(cost.saved)
    }

    public static func unpricedLine(_ usage: TokenUsage) -> String {
        SpendFormat.tokens(usage.total) + " tokens ran on a model with no published price"
    }
}
