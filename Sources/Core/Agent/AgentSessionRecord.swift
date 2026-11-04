import Foundation

public enum AgentSessionRecord {
    public static func write(
        _ settlement: AgentSessionSettlement,
        session: SessionID,
        account: AgentAccountHome?,
        in store: Store
    ) async throws {
        guard let recorded = settlement.recordedAccount else {
            guard settlement.clearsStoredID else { return }
            _ = try await store.update(sessionID: session) { $0.agentSessionID = nil }
            return
        }
        try await AgentAccountAssignment.remember(account, in: store)
        try await store.update(
            sessionID: session, accountID: recorded, clearingConversation: settlement.clearsStoredID
        )
    }
}
