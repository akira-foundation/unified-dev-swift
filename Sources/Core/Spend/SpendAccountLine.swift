import Foundation

public struct SpendAccountLine: Sendable, Equatable, Identifiable {
    public var accountID: AgentAccountID?
    public var name: String
    public var provider: AgentKind
    public var spend: Spend
    public var sessions: [SpendSessionLine]

    public var isKnown: Bool { accountID != nil }

    public var id: String { accountID?.rawValue ?? "\(SpendAccounts.unknown).\(provider.rawValue)" }

    private enum Bucket: Hashable {
        case account(AgentAccountID)
        case unknown(AgentKind)
    }

    static func lines(for days: [SpendDay], input: SpendBoard.Input) -> [SpendAccountLine] {
        let entries = input.accounts.map {
            AgentAccountNames.Entry(home: $0, identity: input.identities[$0.id])
        }
        var attributed: [String: AgentAccountID?] = [:]
        var grouped: [Bucket: [SpendDay]] = [:]
        for row in days {
            let accountID = attributed[row.file] ?? SpendAccounts.accountID(
                ofFile: row.file, among: input.accounts
            )
            attributed[row.file] = .some(accountID)
            let bucket = accountID.map(Bucket.account) ?? .unknown(row.provider)
            grouped[bucket, default: []].append(row)
        }

        return grouped
            .map { bucket, rows in
                line(for: bucket, rows: rows, entries: entries)
            }
            .sorted { left, right in
                if left.spend.cost.total != right.spend.cost.total {
                    return left.spend.cost.total > right.spend.cost.total
                }
                return left.name == right.name ? left.id < right.id : left.name < right.name
            }
    }

    private static func line(
        for bucket: Bucket,
        rows: [SpendDay],
        entries: [AgentAccountNames.Entry]
    ) -> SpendAccountLine {
        let spend = Spend.sum(rows.map(\.spend))
        let sessions = SpendProjectLine.sessions(in: rows)
        switch bucket {
        case .account(let accountID):
            let entry = entries.first { $0.home.id == accountID }
            return SpendAccountLine(
                accountID: accountID,
                name: entry.map { AgentAccountNames.title(of: $0, among: entries) } ?? SpendAccounts.unknown,
                provider: entry?.home.provider ?? rows[0].provider,
                spend: spend,
                sessions: sessions
            )
        case .unknown(let provider):
            return SpendAccountLine(
                accountID: nil, name: SpendAccounts.unknown, provider: provider, spend: spend, sessions: sessions
            )
        }
    }
}
