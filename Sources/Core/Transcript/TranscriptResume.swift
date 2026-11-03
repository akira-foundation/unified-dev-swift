import Foundation

public struct TranscriptPlace: Equatable, Sendable {
    public var anchorSeq: Int
    public var anchorDelta: Double
    public var isAtLiveEnd: Bool
    public var rowCount: Int

    public init(anchorSeq: Int, anchorDelta: Double, isAtLiveEnd: Bool, rowCount: Int) {
        self.anchorSeq = anchorSeq
        self.anchorDelta = anchorDelta
        self.isAtLiveEnd = isAtLiveEnd
        self.rowCount = rowCount
    }
}

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

    public init(place: TranscriptPlace) {
        self.init(
            expanded: [],
            offset: 0,
            anchorSeq: place.anchorSeq,
            anchorDelta: place.anchorDelta,
            isAtLiveEnd: place.isAtLiveEnd,
            rowCount: place.rowCount
        )
    }

    public func leftAtEndAndMissedNothing(rowCount current: Int) -> Bool {
        isAtLiveEnd && current <= rowCount
    }

    public var place: TranscriptPlace? {
        anchorSeq.map {
            TranscriptPlace(
                anchorSeq: $0, anchorDelta: anchorDelta, isAtLiveEnd: isAtLiveEnd, rowCount: rowCount
            )
        }
    }
}

public enum TranscriptPlacement: Equatable, Sendable {
    case first
    case liveEnd
    case offset(Double)
    case row(seq: Int, delta: Double)
    case target(seq: Int)
}

public enum TranscriptResume {
    public static func isResuming(_ remembered: TranscriptPaneState?) -> Bool {
        remembered != nil
    }

    public static func mustReach(
        target: Int?, remembered: TranscriptPaneState?, firstUnread: Int?
    ) -> Int? {
        target ?? (remembered == nil ? firstUnread : nil)
    }

    public static func window<Seqs: RandomAccessCollection>(
        _ remembered: TranscriptPaneState?, tailStart: Int, seqs: Seqs
    ) -> TranscriptWindow where Seqs.Element == Int, Seqs.Index == Int {
        let rowCount = seqs.count
        guard let remembered else {
            return TranscriptWindow.opening(rowCount: rowCount, tailStart: tailStart)
        }
        let anchor = remembered.anchorSeq.flatMap {
            TranscriptWindow.index(ofSeqAtOrAfter: $0, in: seqs)
        }
        if remembered.anchorSeq != nil, anchor == nil {
            return .liveEnd(rowCount: rowCount)
        }
        guard remembered.drawn.count > 0 || anchor != nil else {
            return TranscriptWindow.opening(rowCount: rowCount, tailStart: tailStart)
        }
        var window = remembered.drawn.clamped(rowCount: rowCount)
        if let anchor, !(window.start..<window.end).contains(anchor) {
            if remembered.leftAtEndAndMissedNothing(rowCount: rowCount) {
                return .liveEnd(rowCount: rowCount)
            }
            window = TranscriptWindow.opening(
                rowCount: rowCount, tailStart: tailStart, mustReach: anchor
            )
        }
        if remembered.isAtLiveEnd, rowCount > remembered.rowCount {
            window = window.grownDown(rowCount: rowCount)
        }
        return window
    }

    public static func placement<Seqs: RandomAccessCollection>(
        for remembered: TranscriptPaneState?,
        seqs: Seqs,
        target: Int? = nil
    ) -> TranscriptPlacement where Seqs.Element == Int, Seqs.Index == Int {
        if let target { return .target(seq: target) }
        guard let remembered, !seqs.isEmpty else { return .first }
        if remembered.leftAtEndAndMissedNothing(rowCount: seqs.count) { return .liveEnd }
        if let seq = remembered.anchorSeq {
            guard let index = TranscriptWindow.index(ofSeqAtOrAfter: seq, in: seqs) else {
                return .liveEnd
            }
            let landed = seqs[seqs.startIndex + index]
            return .row(seq: landed, delta: landed == seq ? remembered.anchorDelta : 0)
        }
        if remembered.isAtLiveEnd { return .liveEnd }
        guard remembered.rowCount <= seqs.count else { return .first }
        return .offset(remembered.offset)
    }

    public static func mayNoteSeen(
        arrived: SessionID?, drawnFor: SessionID?, showing: SessionID
    ) -> Bool {
        arrived == showing && drawnFor == showing
    }

    public static func mayRemember(
        arrived: SessionID?, writingTo: SessionID?, drawnRows: Int, paneHeight: Double
    ) -> Bool {
        guard let writingTo, arrived == writingTo else { return false }
        return drawnRows > 0 && paneHeight > 0
    }
}
