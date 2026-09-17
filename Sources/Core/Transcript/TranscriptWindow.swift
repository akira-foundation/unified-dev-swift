import Foundation

public struct TranscriptWindow: Equatable, Sendable {
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    public static let settled = 400

    public static let chunk = 400

    public static let margin = 80

    public static func opening(rowCount: Int, tailStart: Int, mustReach: Int? = nil) -> Self {
        let tail = Self(start: clamp(tailStart, rowCount: rowCount), end: max(0, rowCount))
        guard let mustReach, mustReach < tail.start else { return tail }
        let start = clamp(mustReach - margin, rowCount: rowCount)
        return Self(start: start, end: clamp(start + margin + settled, rowCount: rowCount))
    }

    public static func settling(from window: Self, rowCount: Int) -> Self {
        guard window.end >= rowCount else { return window }
        return Self(
            start: min(window.start, clamp(rowCount - settled, rowCount: rowCount)),
            end: max(0, rowCount)
        )
    }

    public func grownUp(by chunk: Int = chunk) -> Self {
        Self(start: max(0, start - max(0, chunk)), end: end)
    }

    public func preparedHistory(afterArrival arrived: Bool, by chunk: Int = chunk) -> Self? {
        guard arrived, canGrowUp else { return nil }
        return grownUp(by: chunk)
    }

    public func grownDown(rowCount: Int, by chunk: Int = chunk) -> Self {
        Self(start: start, end: min(max(0, rowCount), end + max(0, chunk)))
    }

    public static func liveEnd(rowCount: Int) -> Self {
        Self(start: clamp(rowCount - settled, rowCount: rowCount), end: max(0, rowCount))
    }

    public func indices(outwardFrom anchor: Int) -> [Int] {
        guard count > 0 else { return [] }
        let pinned = min(max(anchor, start), end - 1)
        return (start..<end).sorted { abs($0 - pinned) < abs($1 - pinned) }
    }

    public var canGrowUp: Bool { start > 0 }

    public func canGrowDown(rowCount: Int) -> Bool { end < rowCount }

    public var count: Int { max(0, end - start) }

    public func clamped(rowCount: Int) -> Self {
        let end = Self.clamp(self.end, rowCount: rowCount)
        return Self(start: min(Self.clamp(start, rowCount: rowCount), end), end: end)
    }

    private static func clamp(_ index: Int, rowCount: Int) -> Int {
        min(max(0, index), max(0, rowCount))
    }

    public static func index<Seqs: RandomAccessCollection>(
        ofSeqAtOrAfter seq: Int, in seqs: Seqs
    ) -> Int? where Seqs.Element == Int, Seqs.Index == Int {
        var low = seqs.startIndex
        var high = seqs.endIndex
        while low < high {
            let middle = low + (high - low) / 2
            if seqs[middle] < seq {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low < seqs.endIndex ? low - seqs.startIndex : nil
    }
}
