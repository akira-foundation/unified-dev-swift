import Foundation

public enum DiffHunkHeading {
    public static func text(for hunks: [DiffHunk], at index: Int, revealed: Int) -> String? {
        guard hunks.indices.contains(index) else { return nil }
        guard let gap = DiffGap.between(hunks: hunks, at: index) else { return nil }
        guard DiffGap.hidden(revealed, in: gap) > 0 else { return nil }
        return text(of: hunks[index])
    }

    static func text(of hunk: DiffHunk) -> String {
        let trimmed = hunk.header.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return "@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@"
    }
}
