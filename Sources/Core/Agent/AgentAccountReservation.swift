import Foundation

public struct AgentAccountReservation: Sendable, Hashable {
    public let plan: AgentAccountCreation

    fileprivate init(plan: AgentAccountCreation) {
        self.plan = plan
    }

    @discardableResult
    public func discard(processes: () -> [ProcessVector]? = ProcessVectors.ofOtherProcesses) -> Bool {
        guard plan.directoryExists,
              AgentAccountFolderUse.of(plan.directory, among: processes()) == .free else { return false }
        return (try? FileManager.default.removeItem(at: plan.directory)) != nil
    }

    @discardableResult
    public func discardOnceReleased(
        attempts: Int = 20,
        pause: Duration = .milliseconds(250),
        processes: @Sendable () -> [ProcessVector]? = ProcessVectors.ofOtherProcesses
    ) async -> Bool {
        for attempt in 0..<attempts {
            if attempt > 0 { try? await Task.sleep(for: pause) }
            guard plan.directoryExists else { return false }
            if discard(processes: processes) { return true }
        }
        return false
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
