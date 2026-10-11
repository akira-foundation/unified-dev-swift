import Foundation

public struct SpendSessionLine: Sendable, Equatable, Identifiable {
    public var file: String
    public var agentSessionID: String
    public var models: [String]
    public var spend: Spend
    public var turns: Int
    public var lastDay: Date

    public var id: String { file }

    public var modelLine: String {
        models.isEmpty ? SpendProjectLine.unknownModel : models.joined(separator: ", ")
    }
}

public struct SpendProjectLine: Sendable, Equatable, Identifiable {
    public var repoID: RepoID?
    public var name: String
    public var spend: Spend
    public var sessions: [SpendSessionLine]

    public var id: String { repoID?.rawValue ?? SpendProjects.elsewhere }

    public static let unknownModel = "model not recorded"

    static func lines(for days: [SpendDay], input: SpendBoard.Input) -> [SpendProjectLine] {
        var placements: [String: SpendProjects.Placement] = [:]
        var grouped: [String: (placement: SpendProjects.Placement, rows: [SpendDay])] = [:]
        for row in days {
            let placement = placements[row.directory] ?? SpendProjects.placement(
                of: row.directory, workspaces: input.workspaces, repos: input.repos
            )
            placements[row.directory] = placement
            let key = placement.repoID?.rawValue ?? SpendProjects.elsewhere
            var entry = grouped[key] ?? (placement, [])
            entry.rows.append(row)
            grouped[key] = entry
        }

        return grouped.values
            .map { entry in
                SpendProjectLine(
                    repoID: entry.placement.repoID,
                    name: entry.placement.name,
                    spend: Spend.sum(entry.rows.map(\.spend)),
                    sessions: sessions(in: entry.rows)
                )
            }
            .sorted { left, right in
                left.spend.cost.total == right.spend.cost.total
                    ? left.name < right.name
                    : left.spend.cost.total > right.spend.cost.total
            }
    }

    static func sessions(in rows: [SpendDay]) -> [SpendSessionLine] {
        Dictionary(grouping: rows, by: \.file)
            .values
            .compactMap { group -> SpendSessionLine? in
                guard let first = group.first else { return nil }
                let models = Set(group.map(\.model).filter { !$0.isEmpty }).sorted()
                return SpendSessionLine(
                    file: first.file,
                    agentSessionID: TranscriptSources.agentSessionID(ofFile: first.file),
                    models: models,
                    spend: Spend.sum(group.map(\.spend)),
                    turns: group.reduce(0) { $0 + $1.turns },
                    lastDay: group.map(\.day).max() ?? first.day
                )
            }
            .sorted { left, right in
                left.spend.cost.total == right.spend.cost.total
                    ? left.lastDay > right.lastDay
                    : left.spend.cost.total > right.spend.cost.total
            }
    }
}
