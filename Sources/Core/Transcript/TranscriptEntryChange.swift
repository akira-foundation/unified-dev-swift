import Foundation

public enum TranscriptEntryChange: Equatable, Sendable {
    case same
    case grew(head: Range<Int>, tail: Range<Int>)
    case shrank(head: Range<Int>, tail: Range<Int>)
    case rebuilt

    public var movesRows: Bool { self != .same }

    public static func between<ID: Equatable>(_ old: [ID], _ new: [ID]) -> Self {
        let shortest = min(old.count, new.count)
        var head = 0
        while head < shortest, old[head] == new[head] { head += 1 }
        var tail = 0
        while tail < shortest - head,
              old[old.count - 1 - tail] == new[new.count - 1 - tail] { tail += 1 }

        let oldMiddle = head..<(old.count - tail)
        let newMiddle = head..<(new.count - tail)

        if oldMiddle.isEmpty, newMiddle.isEmpty { return .same }
        if oldMiddle.isEmpty { return .grew(head: newMiddle, tail: 0..<0) }
        if newMiddle.isEmpty { return .shrank(head: oldMiddle, tail: 0..<0) }

        if newMiddle.count > oldMiddle.count,
           let at = start(of: old[oldMiddle], in: new[newMiddle]) {
            let inner = newMiddle.lowerBound + at
            return .grew(
                head: newMiddle.lowerBound..<inner,
                tail: (inner + oldMiddle.count)..<newMiddle.upperBound
            )
        }
        if oldMiddle.count > newMiddle.count,
           let at = start(of: new[newMiddle], in: old[oldMiddle]) {
            let inner = oldMiddle.lowerBound + at
            return .shrank(
                head: oldMiddle.lowerBound..<inner,
                tail: (inner + newMiddle.count)..<oldMiddle.upperBound
            )
        }
        return .rebuilt
    }

    private static func start<ID: Equatable>(
        of inner: ArraySlice<ID>, in outer: ArraySlice<ID>
    ) -> Int? {
        guard let first = inner.first, outer.count >= inner.count else { return nil }
        for offset in 0...(outer.count - inner.count) {
            let at = outer.startIndex + offset
            guard outer[at] == first else { continue }
            var matches = true
            for step in 0..<inner.count where outer[at + step] != inner[inner.startIndex + step] {
                matches = false
                break
            }
            if matches { return offset }
        }
        return nil
    }
}
