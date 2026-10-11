import Foundation

public enum SpendLines {
    public static let title = "Agent spend"
    public static let openScreen = "Open the spend screen"
    public static let keepsNoUsage = "keeps no usage on disk"
    public static let notRead = "not read yet"
    public static let nothingYet = "nothing in this window"
    public static let noPublishedPrice = "no published price"
    public static let whereItWent = "Where it went"
    public static let byProvider = "By provider"
    public static let byProject = "By project"
    public static let dayAxis = "Day"
    public static let costAxis = "Cost"
    public static let providerAxis = "Provider"

    public static func providerLine(_ provider: SpendBoard.ProviderLine) -> String {
        switch provider.reading {
        case .keepsNoUsage:
            keepsNoUsage
        case .notRead:
            notRead
        case .stillReading(let pending):
            stillReading(pending, of: provider.files)
        case .measured:
            provider.spend.isEmpty
                ? nothingYet
                : SpendFormat.tokens(provider.spend.usage.total) + " tokens, " + cost(provider.spend)
        }
    }

    public static func cost(_ spend: Spend) -> String {
        spend.usage == spend.unpriced && !spend.isEmpty
            ? noPublishedPrice
            : SpendFormat.money(spend.cost.total)
    }

    public static func columnCost(_ column: SpendBoard.ColumnLine, in total: Spend) -> String {
        total.usage == total.unpriced && !total.isEmpty
            ? noPublishedPrice
            : SpendFormat.money(column.cost)
    }

    public static func tokensLine(_ count: Int) -> String {
        SpendFormat.tokens(count) + " tokens"
    }

    public static func stillReading(_ pending: Int, of files: Int) -> String {
        files > pending
            ? "still reading \(pending) of \(files) transcripts"
            : "still reading \(pending == 1 ? "1 transcript" : "\(pending) transcripts")"
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
        SpendFormat.tokens(usage.total) + " tokens had " + noPublishedPrice
    }

    public static func dearestDay(_ bar: SpendBoard.DayBar) -> String {
        "Dearest day: " + SpendFormat.day(bar.day) + ", " + cost(bar.spend)
    }
}
