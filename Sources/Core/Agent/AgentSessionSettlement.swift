import Foundation

public struct AgentSessionSettlement: Sendable, Equatable {
    public enum Purpose: Sendable, Equatable {
        case sending
        case answering
    }

    public let recordedAccount: AgentAccountID?
    public let switchTarget: SessionSegmentTarget?

    public static let nothing = AgentSessionSettlement(recordedAccount: nil, switchTarget: nil)

    public var changesNothing: Bool { self == .nothing }

    public static func decide(
        session: Session,
        account: AgentAccountHome?,
        purpose: Purpose
    ) -> AgentSessionSettlement {
        guard purpose == .sending, let account, session.accountID != account.id else { return .nothing }
        let hasHistory = !(session.agentSessionID ?? "").isEmpty
        if session.accountID != nil {
            return AgentSessionSettlement(recordedAccount: nil, switchTarget: SessionSegmentTarget(
                agentKind: session.agentKind, accountID: account.id, model: session.model, effort: session.effort
            ))
        }
        return hasHistory ? .nothing : AgentSessionSettlement(recordedAccount: account.id, switchTarget: nil)
    }

    public static func resumable(session: Session, account: AgentAccountHome?) -> String? {
        guard let account, let owner = session.accountID, owner != account.id else {
            return session.agentSessionID
        }
        return nil
    }

    public static let noSegment =
        "Unified Dev could not find this chat's saved state, so it did not start the agent."

    public static let chatMoved = writeFailure("the chat moved to another account while it was starting.")

    public static func resolutionFailure(_ detail: String) -> String {
        "Unified Dev could not work out which account to run under: \(detail)"
    }

    public static func writeFailure(_ detail: String) -> String {
        "Unified Dev could not record which account this chat runs under, so it did not start the agent: \(detail)"
    }
}
