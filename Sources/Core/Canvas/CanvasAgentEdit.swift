import Foundation

public enum CanvasDiskOutcome: Sendable, Equatable {
    case saved
    case notSaved(String)
    case replaced
}

public struct CanvasAgentEditResult: Sendable, Equatable {
    public var changes: CanvasChangeSummary
    public var operationCount: Int
    public var disk: CanvasDiskOutcome

    public init(changes: CanvasChangeSummary, operationCount: Int, disk: CanvasDiskOutcome) {
        self.changes = changes
        self.operationCount = operationCount
        self.disk = disk
    }
}

public enum CanvasAgentEditOutcome: Sendable, Equatable {
    case applied(CanvasAgentEditResult)
    case conflict([CanvasConflict])
    case refused(String)
}

public struct CanvasPendingAgentEdit: Sendable, Equatable {
    let changes: CanvasChangeSummary
    let operationCount: Int
    let reloadsBefore: Int
}

public enum CanvasAgentEditStart: Sendable, Equatable {
    case refused(String)
    case conflict([CanvasConflict])
    case pending(CanvasPendingAgentEdit)
}

@MainActor
public protocol CanvasKeeperHolding: AnyObject {
    var keeper: CanvasDocumentKeeper { get set }
}

public enum CanvasAgentEdit {
    @MainActor
    public static func begin(
        _ operations: [CanvasOperation], flushing commits: CanvasPendingCommits, in holder: some CanvasKeeperHolding
    ) -> CanvasAgentEditStart {
        commits.flush()
        return begin(operations, on: &holder.keeper)
    }

    public static func refusal(for keeper: CanvasDocumentKeeper) -> String? {
        switch keeper.document {
        case .corrupt(let reason):
            return "This canvas cannot be edited: \(reason)"
        case .newerVersion(let version):
            return "This canvas was saved as version \(version), and this Unified Dev reads up to version \(CanvasDocument.currentVersion)."
        case .document:
            guard let warning = keeper.warning, warning.refusesAgentEdits else { return nil }
            return "Nothing was changed. \(warning.title) in the tab, and the person has to settle that first. \(warning.message)"
        }
    }

    public static func begin(_ operations: [CanvasOperation], on keeper: inout CanvasDocumentKeeper) -> CanvasAgentEditStart {
        if let refusal = refusal(for: keeper) { return .refused(refusal) }
        guard case .document(let before) = keeper.document else { return .refused("This canvas has not been read.") }
        let reloadsBefore = keeper.reloads
        guard let outcome = keeper.apply(operations, by: .agent) else {
            return .refused("This canvas could not be edited right now. Read it with canvas_read and try again.")
        }
        switch outcome {
        case .invalid(let reason):
            return .refused(reason)
        case .conflict(let conflicts):
            return .conflict(conflicts)
        case .applied(let after):
            return .pending(CanvasPendingAgentEdit(
                changes: CanvasChangeSummary(from: before, to: after),
                operationCount: operations.count,
                reloadsBefore: reloadsBefore
            ))
        }
    }

    public static func conclude(_ pending: CanvasPendingAgentEdit, on keeper: CanvasDocumentKeeper) -> CanvasAgentEditResult {
        CanvasAgentEditResult(changes: pending.changes, operationCount: pending.operationCount, disk: disk(reloadsBefore: pending.reloadsBefore, on: keeper))
    }

    static func disk(reloadsBefore: Int, on keeper: CanvasDocumentKeeper) -> CanvasDiskOutcome {
        guard keeper.reloads == reloadsBefore else { return .replaced }
        guard let warning = keeper.warning else { return .saved }
        if case .saveFailed = warning { return .notSaved(warning.title) }
        return warning.refusesAgentEdits ? .notSaved(warning.title) : .saved
    }
}
