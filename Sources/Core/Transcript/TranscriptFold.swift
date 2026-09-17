import Foundation

public enum TranscriptFold {
    public static let freshCall: Duration = .seconds(1)

    public static let leastHidden = 3

    public static let leastWork = 2

    public static func label(hiding count: Int) -> String {
        Counted.of(count, "action")
    }

    public static func refoldedAtLiveEnd(_ unfolded: Set<Int>, in folds: Folds) -> Set<Int> {
        let live = folds.all.reversed().prefix { !$0.hasAnswer }.map(\.firstSeq)
        guard live.contains(where: unfolded.contains) else { return unfolded }
        var result = unfolded
        result.subtract(live)
        return result
    }

    public static func mayAdopt(_ fresh: Folds, over stale: Folds, drawn: Range<Int>) -> Bool {
        guard fresh.all.count == stale.all.count,
              let new = fresh.all.last, let old = stale.all.last,
              new.firstSeq == old.firstSeq,
              new.span.upperBound <= drawn.upperBound else { return false }

        return lastExposedSeq(new) <= lastExposedSeq(old)
    }

    private static func lastExposedSeq(_ work: Work) -> Int {
        guard let last = work.rows.last(where: { !work.ready.contains($0.index) }) else { return .min }
        return last.seq
    }

    public static func hiddenIndices(_ work: Work, revealed: Set<Int>, drawn: Range<Int>) -> Set<Int> {
        guard work.span.upperBound <= drawn.upperBound else { return [] }
        var hidden = work.ready
        if !revealed.isEmpty,
           let stop = work.rows.first(where: { revealed.contains($0.seq) }) {
            hidden = hidden.filter { $0 < stop.index }
        }
        return hidden.count >= leastHidden ? hidden : []
    }

    public struct Fact: Equatable, Sendable {
        public var seq: Int
        public var kind: MessageKind
        public var failed: Bool
        public var featured: Bool
        public var drawsNothing: Bool
        public var settled: Bool
        public var isFresh: Bool
        public var toolUseID: String?
        public var parentToolUseID: String?
        public var opensTurn: Bool

        public init(
            seq: Int,
            kind: MessageKind,
            failed: Bool = false,
            featured: Bool = false,
            drawsNothing: Bool = false,
            settled: Bool = true,
            isFresh: Bool = false,
            toolUseID: String? = nil,
            parentToolUseID: String? = nil,
            opensTurn: Bool = false
        ) {
            self.seq = seq
            self.kind = kind
            self.failed = failed
            self.featured = featured
            self.drawsNothing = drawsNothing
            self.settled = settled
            self.isFresh = isFresh
            self.toolUseID = toolUseID
            self.parentToolUseID = parentToolUseID
            self.opensTurn = opensTurn
        }

        var isActivity: Bool {
            switch kind {
            case .toolUse, .thinking, .permissionAsk, .notice, .system, .error: !drawsNothing
            case .assistantText, .user, .toolResult, .result, .crew: false
            }
        }

        var mustShow: Bool { featured || kind == .error }

        var surfaces: Bool {
            guard !drawsNothing else { return false }
            return mustShow || (kind == .permissionAsk && !settled)
        }
    }

    public struct Subagent: Equatable, Sendable {
        public var callIndex: Int
        public var actions: Int
        var settledActions: Int

        public init(callIndex: Int, actions: Int = 0, settledActions: Int = 0) {
            self.callIndex = callIndex
            self.actions = actions
            self.settledActions = settledActions
        }
    }

    public struct Row: Equatable, Sendable {
        public var index: Int
        public var seq: Int

        public init(index: Int, seq: Int) {
            self.index = index
            self.seq = seq
        }
    }

    private struct Item {
        var row: Row
        var ready: Bool
        var mustShow: Bool
        var parentToolUseID: String?
    }

    public struct Work: Equatable, Sendable {
        public var span: Range<Int>
        public var rows: [Row]
        public var ready: Set<Int>
        public var hasAnswer: Bool
        public var isNested: Bool

        public var firstSeq: Int { rows.first?.seq ?? 0 }

        public init(
            span: Range<Int>, rows: [Row], ready: Set<Int>, hasAnswer: Bool, isNested: Bool = false
        ) {
            self.span = span
            self.rows = rows
            self.ready = ready
            self.hasAnswer = hasAnswer
            self.isNested = isNested
        }
    }

    public struct Folds: Equatable, Sendable {
        public var all: [Work]
        public var scannedRows: Int
        public var resumeIndex: Int
        public var subagents: [String: Subagent]
        var roots: [String: String]
        var orphans: Set<String>
        var surfaced: Set<Int>

        public static let none = Folds(all: [], scannedRows: 0, resumeIndex: 0)

        public init(
            all: [Work],
            scannedRows: Int,
            resumeIndex: Int,
            subagents: [String: Subagent] = [:],
            roots: [String: String] = [:],
            orphans: Set<String> = [],
            surfaced: Set<Int> = []
        ) {
            self.all = all
            self.scannedRows = scannedRows
            self.resumeIndex = resumeIndex
            self.subagents = subagents
            self.roots = roots
            self.orphans = orphans
            self.surfaced = surfaced
        }

        public func absorbs(index: Int, seq: Int, parent: String?, revealed: Set<Int>) -> Bool {
            guard parent != nil, !revealed.contains(seq) else { return false }
            guard index < scannedRows else { return true }
            guard let parent, roots[parent] != nil else { return false }
            return !surfaced.contains(index)
        }

        public func hasRun(underCall toolUseID: String?) -> Bool {
            guard !subagents.isEmpty, let toolUseID else { return false }
            return subagents[toolUseID] != nil
        }

        public func actions(underCall toolUseID: String?) -> Int? {
            guard !subagents.isEmpty, let toolUseID, let subagent = subagents[toolUseID],
                  subagent.actions > 0 else { return nil }
            return subagent.actions
        }

        public func index(containing index: Int) -> Int? {
            var low = 0
            var high = all.count
            while low < high {
                let middle = low + (high - low) / 2
                if all[middle].span.upperBound <= index {
                    low = middle + 1
                } else if index < all[middle].span.lowerBound {
                    high = middle
                } else {
                    return middle
                }
            }
            return nil
        }

        public func fold(containing index: Int) -> Work? {
            self.index(containing: index).map { all[$0] }
        }
    }

    public static func folds<Facts: RandomAccessCollection>(
        in facts: Facts, extending previous: Folds = .none
    ) -> Folds where Facts.Element == Fact, Facts.Index == Int {
        let count = facts.count
        var start = previous.resumeIndex
        var found: [Work] = []
        var subagents: [String: Subagent] = [:]
        var roots: [String: String] = [:]
        var orphans: Set<String> = []
        var surfaced: Set<Int> = []
        if count < previous.scannedRows || start > count {
            start = 0
        } else {
            found = previous.all.filter { $0.span.upperBound <= start }
            for (id, subagent) in previous.subagents where subagent.callIndex < start {
                subagents[id] = Subagent(
                    callIndex: subagent.callIndex,
                    actions: subagent.settledActions,
                    settledActions: subagent.settledActions
                )
            }
            roots = previous.roots.filter { subagents[$0.value] != nil }
            orphans = previous.orphans
            surfaced = previous.surfaced.filter { $0 < start }
        }
        var calls: [String: (index: Int, parent: String?)] = [:]
        var counted: [(root: String, index: Int)] = []

        var items: [Item] = []
        var resume = start

        func close(hasAnswer: Bool) {
            defer { items = [] }
            var segmentStart = items.startIndex

            func appendSegment(endingAt segmentEnd: Int) {
                let segment = items[segmentStart..<segmentEnd]
                guard segment.count >= leastWork,
                      let first = segment.first,
                      let last = segment.last else { return }
                found.append(Work(
                    span: first.row.index..<(last.row.index + 1),
                    rows: segment.map(\.row),
                    ready: Set(segment.lazy.filter(\.ready).map { $0.row.index }),
                    hasAnswer: hasAnswer,
                    isNested: first.parentToolUseID != nil
                ))
            }

            for index in items.indices where items[index].mustShow {
                appendSegment(endingAt: index)
                segmentStart = items.index(after: index)
            }
            appendSegment(endingAt: items.endIndex)
        }

        func root(of parent: String) -> String? {
            if let known = roots[parent] { return known }
            if orphans.contains(parent) { return nil }
            var call = calls[parent]
            if call == nil {
                var at = start - 1
                while at >= 0 {
                    let earlier = facts[facts.index(facts.startIndex, offsetBy: at)]
                    if earlier.kind == .toolUse, earlier.toolUseID == parent {
                        call = (at, earlier.parentToolUseID)
                        break
                    }
                    at -= 1
                }
            }
            guard let call else {
                orphans.insert(parent)
                return nil
            }
            let top = call.parent.flatMap { root(of: $0) } ?? parent
            roots[parent] = top
            if top == parent {
                subagents[parent] = Subagent(callIndex: call.index)
                if let header = items.lastIndex(where: { $0.row.index == call.index }) {
                    items[header].mustShow = true
                }
            }
            return top
        }

        for offset in start..<count {
            let fact = facts[facts.index(facts.startIndex, offsetBy: offset)]
            if let parent = fact.parentToolUseID, let top = root(of: parent) {
                if fact.surfaces { surfaced.insert(offset) }
                if fact.isActivity {
                    subagents[top]?.actions += 1
                    counted.append((top, offset))
                }
                if fact.kind == .toolUse, let id = fact.toolUseID { calls[id] = (offset, parent) }
                continue
            }
            if fact.kind == .toolUse, let id = fact.toolUseID {
                calls[id] = (offset, fact.parentToolUseID)
            }
            if fact.kind == .user || fact.kind == .crew || fact.kind == .result || fact.opensTurn {
                close(hasAnswer: false)
                resume = offset + 1
                continue
            }
            if fact.kind == .assistantText {
                close(hasAnswer: true)
                continue
            }
            if fact.drawsNothing { continue }
            guard fact.isActivity else { continue }
            if let last = items.last, last.parentToolUseID != fact.parentToolUseID {
                close(hasAnswer: false)
            }
            items.append(Item(
                row: Row(index: offset, seq: fact.seq),
                ready: fact.settled || fact.failed || (fact.isFresh && fact.kind == .toolUse),
                mustShow: fact.mustShow,
                parentToolUseID: fact.parentToolUseID
            ))
        }
        close(hasAnswer: false)

        let resumeIndex = min(resume, count)
        for child in counted where child.index < resumeIndex {
            subagents[child.root]?.settledActions += 1
        }
        return Folds(
            all: found,
            scannedRows: count,
            resumeIndex: resumeIndex,
            subagents: subagents,
            roots: roots,
            orphans: orphans,
            surfaced: surfaced
        )
    }
}
