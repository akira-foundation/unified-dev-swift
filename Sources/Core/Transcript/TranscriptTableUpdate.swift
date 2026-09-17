import Foundation

public enum TranscriptTableUpdate {
    public enum Plan: Equatable, Sendable {
        case nothing
        case rows(TranscriptEntryChange)
        case reload
    }

    public static func plan(change: TranscriptEntryChange, environmentMoved: Bool) -> Plan {
        if environmentMoved || change == .rebuilt { return .reload }
        return change == .same ? .nothing : .rows(change)
    }
}
