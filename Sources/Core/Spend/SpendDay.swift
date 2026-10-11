import Foundation

public struct SpendDay: Sendable, Hashable {
    public var provider: AgentKind
    public var day: Date
    public var model: String
    public var directory: String
    public var agentSessionID: String
    public var file: String
    public var usage: TokenUsage
    public var turns: Int

    public init(
        provider: AgentKind,
        day: Date,
        model: String,
        directory: String,
        agentSessionID: String,
        file: String,
        usage: TokenUsage,
        turns: Int
    ) {
        self.provider = provider
        self.day = day
        self.model = model
        self.directory = directory
        self.agentSessionID = agentSessionID
        self.file = file
        self.usage = usage
        self.turns = turns
    }

    public var spend: Spend { ModelPrices.spend(of: usage, model: model, provider: provider) }
}

public enum SpendDays {
    public static func days(
        for records: [SpendRecord],
        in file: TranscriptFile,
        calendar: Calendar
    ) -> [SpendDay] {
        var totals: [Key: (usage: TokenUsage, turns: Int)] = [:]
        for record in records {
            let key = Key(
                day: calendar.startOfDay(for: record.happenedAt),
                model: record.model,
                directory: record.directory
            )
            var entry = totals[key] ?? (.none, 0)
            entry.usage += record.usage
            entry.turns += 1
            totals[key] = entry
        }

        return totals.map { key, entry in
            SpendDay(
                provider: file.provider,
                day: key.day,
                model: key.model,
                directory: key.directory,
                agentSessionID: file.agentSessionID,
                file: file.url.path,
                usage: entry.usage,
                turns: entry.turns
            )
        }
        .sorted { $0.day < $1.day }
    }

    struct Key: Hashable {
        var day: Date
        var model: String
        var directory: String
    }
}
