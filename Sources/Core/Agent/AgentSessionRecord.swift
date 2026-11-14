import Foundation

public enum AgentSessionRecord {
    public static func write(
        _ settlement: AgentSessionSettlement,
        session: SessionID,
        account: AgentAccountHome?,
        accountName: String? = nil,
        in store: Store
    ) async throws {
        guard !settlement.changesNothing else { return }
        try await AgentAccountAssignment.remember(account, in: store)
        if let target = settlement.switchTarget {
            try await store.switchSegment(sessionID: session, to: target.named(accountName))
            return
        }
        if let recorded = settlement.recordedAccount {
            try await store.update(sessionID: session, accountID: recorded)
        }
    }
}
