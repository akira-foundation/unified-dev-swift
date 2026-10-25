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
        case account(AgentAccountHome)
        case unknown(AgentKind)
    }

    static func lines(for days: [SpendDay], input: SpendBoard.Input) -> [SpendAccountLine] {
        let directories = SpendAccounts.Directories(input.accounts)
        var attributed: [String: AgentAccountHome?] = [:]
        var grouped: [Bucket: [SpendDay]] = [:]
        for row in days {
            let account = attributed[row.file] ?? directories.account(ofFile: row.file)
            attributed[row.file] = .some(account)
            let bucket = account.map(Bucket.account) ?? .unknown(row.provider)
            grouped[bucket, default: []].append(row)
        }

        return grouped
            .map { bucket, rows in
                line(for: bucket, rows: rows, input: input)
            }
            .sorted { left, right in
                if left.spend.cost.total != right.spend.cost.total {
                    return left.spend.cost.total > right.spend.cost.total
                }
                return left.name == right.name ? left.id < right.id : left.name < right.name
            }
    }

    private static func line(for bucket: Bucket, rows: [SpendDay], input: SpendBoard.Input) -> SpendAccountLine {
        let spend = Spend.sum(rows.map(\.spend))
        let sessions = SpendProjectLine.sessions(in: rows)
        switch bucket {
        case .account(let home):
            return SpendAccountLine(
                accountID: home.id,
                name: name(of: home, identity: input.identities[home.id]),
                provider: home.provider,
                spend: spend,
                sessions: sessions
            )
        case .unknown(let provider):
            return SpendAccountLine(
                accountID: nil, name: SpendAccounts.unknown, provider: provider, spend: spend, sessions: sessions
            )
        }
    }

    private static func name(of home: AgentAccountHome, identity: AgentAccountIdentity?) -> String {
        if let email = identity?.email, !email.isEmpty { return email }
        return home.directory.lastPathComponent
    }
}
