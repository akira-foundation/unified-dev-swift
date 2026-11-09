import Foundation

public struct SpendRoster: Sendable, Equatable {
    public let accounts: [AgentAccountHome]
    public let identities: [AgentAccountID: AgentAccountIdentity]

    public init(accounts: [AgentAccountHome], identities: [AgentAccountID: AgentAccountIdentity] = [:]) {
        self.accounts = accounts
        self.identities = identities
    }

    public init(standings: [AgentAccountStanding]) {
        self.init(
            accounts: standings.map(\.home),
            identities: Dictionary(standings.map { ($0.home.id, $0.identity) }, uniquingKeysWith: { first, _ in first })
        )
    }

    public static func read(
        store: Store,
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes()
    ) async throws -> SpendRoster {
        SpendRoster(standings: await AgentAccountInventory.standingsWithoutAsking(
            rows: try await store.agentAccounts(), defaults: defaults
        ))
    }

    public static func homes(
        store: Store,
        defaults: [AgentAccountHome]
    ) async throws -> [AgentAccountHome] {
        AgentAccountRoster.homes(rows: try await store.agentAccounts(), defaults: defaults)
    }
}

extension SpendBoard {
    public static func accounts(
        _ input: Input,
        reading store: Store,
        in profile: ProfileID? = nil,
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes()
    ) async throws -> [SpendAccountLine] {
        let roster = try await SpendRoster.read(store: store, defaults: defaults)
        var read = input
        read.accounts = roster.accounts
        read.identities = roster.identities
        let lines = accountLines(read)
        guard let profile else { return lines }
        return try await store.profileAccounts().spendLines(lines, in: profile)
    }
}

extension SpendBoard {
    public static func accountsState(
        _ input: Input,
        reading store: Store,
        in profile: ProfileID? = nil,
        defaults: [AgentAccountHome] = SpendAccounts.defaultHomes()
    ) async -> SpendAccountsState {
        switch input.standing {
        case .notRead: return .notRead
        case .failed: return .failed
        case .kept, .current: break
        }
        do {
            let lines = try await accounts(input, reading: store, in: profile, defaults: defaults)
            return input.standing == .kept && lines.isEmpty ? .failed : .read(lines)
        } catch {
            return .failed
        }
    }
}
