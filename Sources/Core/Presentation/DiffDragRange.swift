import Foundation

public enum DiffDragRange {
    public static func row(
        from start: Int,
        translation: CGFloat,
        rowHeight: CGFloat,
        count: Int
    ) -> Int {
        guard count > 0 else { return 0 }
        guard rowHeight > 0 else { return min(max(start, 0), count - 1) }
        let moved = Int((translation / rowHeight).rounded())
        return min(max(start + moved, 0), count - 1)
    }

    public static func row(at offset: CGFloat, heights: [CGFloat]) -> Int? {
        guard offset >= 0, offset.isFinite else { return nil }
        var end: CGFloat = 0
        for (index, height) in heights.enumerated() {
            end += height
            if offset < end { return index }
        }
        return nil
    }

    public static func spot(
        from start: Int,
        translation: CGFloat,
        rowHeight: CGFloat,
        rowHeights: [CGFloat]? = nil,
        spots: [ReviewSpot?],
        side: ReviewCommentSide
    ) -> ReviewSpot? {
        let target: Int
        if let rowHeights, rowHeights.count == spots.count, rowHeights.indices.contains(start) {
            let y = rowHeights.prefix(start).reduce(0, +) + rowHeight / 2 + translation
            target = row(at: max(0, y), heights: rowHeights) ?? max(0, spots.count - 1)
        } else {
            target = row(from: start, translation: translation, rowHeight: rowHeight, count: spots.count)
        }
        guard spots.indices.contains(target), spots.indices.contains(start) else { return nil }
        let step = target >= start ? -1 : 1
        var index = target
        while spots.indices.contains(index) {
            if let spot = spots[index], spot.side == side { return spot }
            if index == start { return nil }
            index += step
        }
        return nil
    }
}
