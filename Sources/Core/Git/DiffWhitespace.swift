import Foundation

public extension FileDiff {
    func ignoringWhitespace() -> FileDiff {
        var folded = self
        var additions = 0
        var deletions = 0

        folded.hunks = hunks.compactMap { hunk in
            var rewritten = hunk
            rewritten.lines = Self.fold(hunk.lines)

            let changed = rewritten.lines.filter { $0.kind == .addition || $0.kind == .deletion }
            guard !changed.isEmpty else { return nil }

            additions += changed.lazy.filter { $0.kind == .addition }.count
            deletions += changed.lazy.filter { $0.kind == .deletion }.count
            return rewritten
        }

        folded.additions = additions
        folded.deletions = deletions
        return folded
    }

    private static func fold(_ lines: [DiffLine]) -> [DiffLine] {
        var result: [DiffLine] = []
        result.reserveCapacity(lines.count)
        var index = 0

        while index < lines.count {
            guard lines[index].kind == .addition || lines[index].kind == .deletion else {
                result.append(lines[index])
                index += 1
                continue
            }

            var end = index
            while end < lines.count,
                  lines[end].kind == .addition || lines[end].kind == .deletion {
                end += 1
            }

            let block = lines[index..<end]
            result.append(contentsOf: folded(block) ?? Array(block))
            index = end
        }
        return result
    }

    private static func folded(_ block: ArraySlice<DiffLine>) -> [DiffLine]? {
        let removed = block.filter { $0.kind == .deletion }
        let added = block.filter { $0.kind == .addition }
        guard removed.count == added.count, !removed.isEmpty else { return nil }

        for (before, after) in zip(removed, added) where squeezed(before.text) != squeezed(after.text) {
            return nil
        }

        return zip(removed, added).map { before, after in
            DiffLine(
                kind: .context,
                text: after.text,
                oldNumber: before.oldNumber,
                newNumber: after.newNumber,
                index: after.index
            )
        }
    }

    private static func squeezed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }
}
