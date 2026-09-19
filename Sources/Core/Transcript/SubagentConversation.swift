import Foundation

public enum SubagentConversation {
    public enum Entry: Equatable, Sendable {
        case fold(firstSeq: Int, hiding: Int, showsMore: Bool, isFolded: Bool)
        case row(index: Int, seq: Int)

        public var id: Identity {
            switch self {
            case .fold(let firstSeq, _, _, _): .fold(firstSeq)
            case .row(_, let seq): .row(seq)
            }
        }
    }

    public enum Identity: Hashable, Sendable {
        case fold(Int)
        case row(Int)
    }

    public static func entries(
        facts: [TranscriptFold.Fact], unfolded: Set<Int>, revealed: Set<Int>
    ) -> [Entry] {
        let flat = facts.map { fact in
            var own = fact
            own.parentToolUseID = nil
            return own
        }
        let folds = TranscriptFold.folds(in: flat)
        let drawn = 0..<flat.count

        var out: [Entry] = []
        var foldSeq: Int?
        var hidden: Set<Int> = []
        for index in flat.indices {
            if let at = folds.index(containing: index) {
                let work = folds.all[at]
                if work.firstSeq != foldSeq {
                    foldSeq = work.firstSeq
                    let would = TranscriptFold.hiddenIndices(work, revealed: revealed, drawn: drawn)
                    hidden = unfolded.contains(work.firstSeq) ? [] : would
                    let isFolded = !hidden.isEmpty
                    if !would.isEmpty {
                        out.append(.fold(
                            firstSeq: work.firstSeq,
                            hiding: isFolded ? would.count : work.rows.count,
                            showsMore: isFolded && would.count < work.rows.count,
                            isFolded: isFolded
                        ))
                    }
                }
                if hidden.contains(index) { continue }
            }
            guard !flat[index].drawsNothing else { continue }
            out.append(.row(index: index, seq: flat[index].seq))
        }
        return out
    }
}
