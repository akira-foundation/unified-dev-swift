public struct TranscriptFoldCache: Sendable {
    private var held = TranscriptFold.Folds.none
    private var dirty = true

    public init() {}

    public mutating func reset() {
        held = .none
        dirty = true
    }

    public mutating func invalidate(row index: Int) {
        if index < held.resumeIndex { held = .none }
        dirty = true
    }

    public mutating func resolve<Facts: RandomAccessCollection>(
        _ facts: Facts
    ) -> TranscriptFold.Folds where Facts.Element == TranscriptFold.Fact, Facts.Index == Int {
        guard dirty || held.scannedRows != facts.count else { return held }
        held = TranscriptFold.folds(in: facts, extending: held)
        dirty = false
        return held
    }
}
