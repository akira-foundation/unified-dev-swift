import Foundation

public struct TranscriptRowContentKey: Hashable, Sendable {
    public var id: Int64
    public var seq: Int
    public var kind: MessageKind
    public var isError: Bool
    public var durationMS: Int?
    public var resultPayloadCount: Int?
    public var permissionDecision: String?
    public var permissionNote: String
    public var parentToolUseID: String?
    public var isExpanded: Bool
    public var subagentActions: Int?
    public var subagentHasRun: Bool
    public var wasStopped: Bool
    public var wasRecovered: Bool
    public var closesTranscript: Bool
    public var stillRunning: String?
    public var suggestion: WorkSuggestion?

    public init(
        id: Int64,
        seq: Int,
        kind: MessageKind,
        isError: Bool,
        durationMS: Int?,
        resultPayloadCount: Int?,
        permissionDecision: String?,
        permissionNote: String,
        parentToolUseID: String?,
        isExpanded: Bool,
        subagentActions: Int?,
        subagentHasRun: Bool,
        wasStopped: Bool,
        wasRecovered: Bool,
        closesTranscript: Bool,
        stillRunning: String?,
        suggestion: WorkSuggestion?
    ) {
        self.id = id
        self.seq = seq
        self.kind = kind
        self.isError = isError
        self.durationMS = durationMS
        self.resultPayloadCount = resultPayloadCount
        self.permissionDecision = permissionDecision
        self.permissionNote = permissionNote
        self.parentToolUseID = parentToolUseID
        self.isExpanded = isExpanded
        self.subagentActions = subagentActions
        self.subagentHasRun = subagentHasRun
        self.wasStopped = wasStopped
        self.wasRecovered = wasRecovered
        self.closesTranscript = closesTranscript
        self.stillRunning = stillRunning
        self.suggestion = suggestion
    }

    public var contentKey: TranscriptContentKey {
        TranscriptContentKey { $0.combine(self) }
    }
}
