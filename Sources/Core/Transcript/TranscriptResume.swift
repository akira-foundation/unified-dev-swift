import Foundation

public struct TranscriptPaneState: Equatable, Sendable {
    public struct Key: Hashable, Sendable {
        public var pane: String
        public var session: SessionID

        public init(pane: String, session: SessionID) {
            self.pane = pane
            self.session = session
        }
    }

    public var expanded: Set<Int>
    public var unfolded: Set<Int>
    public var offset: Double

    public var anchorSeq: Int?
    public var anchorDelta: Double
    public var isAtLiveEnd: Bool
    public var rowCount: Int
    public var drawn: TranscriptWindow

    public var liveEndRequest: Int

    public init(
        expanded: Set<Int>,
        unfolded: Set<Int> = [],
        offset: Double,
        anchorSeq: Int? = nil,
        anchorDelta: Double = 0,
        isAtLiveEnd: Bool,
        rowCount: Int,
        drawn: TranscriptWindow = TranscriptWindow(start: 0, end: 0),
        liveEndRequest: Int = 0
    ) {
        self.expanded = expanded
        self.unfolded = unfolded
        self.offset = offset
        self.anchorSeq = anchorSeq
        self.anchorDelta = anchorDelta
        self.isAtLiveEnd = isAtLiveEnd
        self.rowCount = rowCount
        self.drawn = drawn
        self.liveEndRequest = liveEndRequest
    }
}

public enum TranscriptPlacement: Equatable, Sendable {
    case first
    case liveEnd
    case offset(Double)
    case row(seq: Int, delta: Double)
}

public enum TranscriptResume {
    public static func isResuming(_ remembered: TranscriptPaneState?) -> Bool {
        remembered != nil
    }

    public static func window(
        _ remembered: TranscriptPaneState?, tailStart: Int, rowCount: Int
    ) -> TranscriptWindow {
        guard let remembered, remembered.drawn.count > 0 else {
            return TranscriptWindow.opening(rowCount: rowCount, tailStart: tailStart)
        }
        return remembered.drawn.clamped(rowCount: rowCount)
    }

    public static func placement(
        for remembered: TranscriptPaneState?,
        rowCount: Int
    ) -> TranscriptPlacement {
        guard let remembered, rowCount > 0 else { return .first }
        guard remembered.rowCount <= rowCount else { return .first }
        if remembered.isAtLiveEnd { return .liveEnd }
        if let seq = remembered.anchorSeq { return .row(seq: seq, delta: remembered.anchorDelta) }
        return .offset(remembered.offset)
    }

    public static func mayRemember(
        arrived: SessionID?, writingTo: SessionID?, drawnRows: Int, paneHeight: Double
    ) -> Bool {
        guard let writingTo, arrived == writingTo else { return false }
        return drawnRows > 0 && paneHeight > 0
    }
}
