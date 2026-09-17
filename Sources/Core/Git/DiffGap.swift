import Foundation

public enum DiffGap {
    public static func between(hunks: [DiffHunk], at index: Int) -> Range<Int>? {
        guard hunks.indices.contains(index) else { return nil }
        let hunk = hunks[index]
        let previousEnd = index == 0
            ? 1
            : hunks[index - 1].newStart + hunks[index - 1].newCount
        guard hunk.newStart > previousEnd else { return nil }
        return previousEnd..<hunk.newStart
    }

    public static func revealed(_ requested: Int, in gap: Range<Int>) -> Range<Int> {
        let count = min(max(requested, 0), gap.count)
        return (gap.upperBound - count)..<gap.upperBound
    }

    public static func hidden(_ requested: Int, in gap: Range<Int>) -> Int {
        gap.count - revealed(requested, in: gap).count
    }
}
