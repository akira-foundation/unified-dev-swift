import Foundation

public struct SpendTurn: Sendable, Hashable {
    public var file: String
    public var key: String
    public var provider: AgentKind
    public var day: Date
    public var model: String
    public var directory: String
    public var tier: PriceTier
    public var usage: TokenUsage

    public init(
        file: String,
        key: String,
        provider: AgentKind,
        day: Date,
        model: String,
        directory: String,
        tier: PriceTier,
        usage: TokenUsage
    ) {
        self.file = file
        self.key = key
        self.provider = provider
        self.day = day
        self.model = model
        self.directory = directory
        self.tier = tier
        self.usage = usage
    }
}

public enum SpendTurns {
    public static func turns(
        for records: [SpendRecord],
        in file: TranscriptFile,
        calendar: Calendar
    ) -> [SpendTurn] {
        records.map { record in
            SpendTurn(
                file: file.url.path,
                key: record.storedKey(inFile: file.url.path),
                provider: record.provider,
                day: calendar.startOfDay(for: record.happenedAt),
                model: record.model,
                directory: record.directory,
                tier: ModelPrices.tier(
                    for: record.model, provider: record.provider, prompt: record.usage.prompt
                ),
                usage: record.usage
            )
        }
    }
}
