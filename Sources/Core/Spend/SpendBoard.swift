import Foundation

public struct SpendBoard: Sendable, Equatable {
    public struct Input: Sendable {
        public var days: [SpendDay]
        public var workspaces: [Workspace]
        public var repos: [Repo]
        public var census: SpendCensus
        public var installed: Set<AgentKind>
        public var window: SpendSpan
        public var now: Date
        public var calendar: Calendar

        public init(
            days: [SpendDay],
            workspaces: [Workspace] = [],
            repos: [Repo] = [],
            census: SpendCensus = SpendCensus(),
            installed: Set<AgentKind> = [],
            window: SpendSpan = .week,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            self.days = days
            self.workspaces = workspaces
            self.repos = repos
            self.census = census
            self.installed = installed
            self.window = window
            self.now = now
            self.calendar = calendar
        }
    }

    public enum Reading: Sendable, Equatable {
        case measured
        case keepsNoUsage
        case notRead
        case stillReading(pending: Int)
    }

    public struct ProviderLine: Sendable, Equatable, Identifiable {
        public var kind: AgentKind
        public var reading: Reading
        public var spend: Spend
        public var turns: Int

        public var id: AgentKind { kind }
    }

    public struct DayBar: Sendable, Equatable, Identifiable {
        public var day: Date
        public var spend: Spend

        public var id: Date { day }
    }

    public struct ColumnLine: Sendable, Equatable, Identifiable {
        public var column: TokenColumn
        public var tokens: Int
        public var cost: Double
        public var tokenShare: Double
        public var costShare: Double

        public var id: TokenColumn { column }
    }

    public var window: SpendSpan
    public var total: Spend
    public var columns: [ColumnLine]
    public var bars: [DayBar]
    public var providers: [ProviderLine]
    public var projects: [SpendProjectLine]
    public var pricedOn: Date

    public static let pricedNote = "At API rates, priced"
    public static let emptyLine = "No agent turns in this window."
    public static let unpricedNote = "Some turns ran on a model with no published price."

    public static func make(_ input: Input) -> SpendBoard {
        let start = input.window.start(from: input.now, calendar: input.calendar)
        let kept = input.days.filter { $0.day >= start }
        let total = Spend.sum(kept.map(\.spend))

        return SpendBoard(
            window: input.window,
            total: total,
            columns: columns(total),
            bars: bars(kept, input: input),
            providers: providers(kept, input: input),
            projects: SpendProjectLine.lines(for: kept, input: input),
            pricedOn: ModelPrices.measuredOn
        )
    }

    static func columns(_ total: Spend) -> [ColumnLine] {
        let tokens = Double(total.usage.total)
        let cost = total.cost.total
        return TokenColumn.allCases.map { column in
            let counted = column.tokens(in: total.usage)
            let amount = total.cost.amount(of: column)
            return ColumnLine(
                column: column,
                tokens: counted,
                cost: amount,
                tokenShare: tokens > 0 ? Double(counted) / tokens : 0,
                costShare: cost > 0 ? amount / cost : 0
            )
        }
    }

    static func bars(_ days: [SpendDay], input: Input) -> [DayBar] {
        let byDay = Dictionary(grouping: days, by: \.day)
        return input.window.dayStarts(from: input.now, calendar: input.calendar).map { day in
            DayBar(day: day, spend: Spend.sum((byDay[day] ?? []).map(\.spend)))
        }
    }

    static func providers(_ days: [SpendDay], input: Input) -> [ProviderLine] {
        let byProvider = Dictionary(grouping: days, by: \.provider)
        return AgentKind.allCases
            .filter { input.installed.contains($0) || byProvider[$0] != nil }
            .map { kind in
                let rows = byProvider[kind] ?? []
                return ProviderLine(
                    kind: kind,
                    reading: reading(for: kind, rows: rows, census: input.census),
                    spend: Spend.sum(rows.map(\.spend)),
                    turns: rows.reduce(0) { $0 + $1.turns }
                )
            }
    }

    static func reading(for kind: AgentKind, rows: [SpendDay], census: SpendCensus) -> Reading {
        guard let seen = census[kind] else { return .notRead }
        if !seen.keepsTranscripts { return .keepsNoUsage }
        if seen.pending > 0 { return .stillReading(pending: seen.pending) }
        return .measured
    }

    public var hasSpend: Bool { !total.isEmpty }
}
