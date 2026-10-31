import Foundation

public struct AgentAccountReservation: Sendable, Hashable {
    public let plan: AgentAccountCreation

    fileprivate init(plan: AgentAccountCreation) {
        self.plan = plan
    }

    @discardableResult
    public func discard() -> Bool {
        guard plan.directoryExists else { return false }
        return (try? FileManager.default.removeItem(at: plan.directory)) != nil
    }
}

extension AgentAccountCreation {
    public static func reserve(
        provider: AgentKind,
        label: String,
        existing: [AgentAccountID],
        support: URL,
        discriminant: String = freshDiscriminant()
    ) throws -> AgentAccountReservation {
        let made = plan(
            provider: provider,
            label: label,
            existing: existing + occupiedIDs(support: support),
            support: support,
            discriminant: discriminant
        )
        guard !made.directoryExists else { throw AgentAccountError.folderAlreadyThere(made.directory.path) }
        try prepareDirectory(of: made.home)
        return AgentAccountReservation(plan: made)
    }
}
