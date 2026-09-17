import Foundation

public struct ReviewSpot: Sendable, Hashable, Codable {
    public var side: ReviewCommentSide
    public var line: Int

    public init(side: ReviewCommentSide, line: Int) {
        self.side = side
        self.line = line
    }
}

public struct ReviewSelection: Sendable, Hashable {
    public var side: ReviewCommentSide
    public var start: Int
    public var end: Int

    public init(side: ReviewCommentSide, start: Int, end: Int) {
        self.side = side
        self.start = min(start, end)
        self.end = max(start, end)
    }

    public init(_ spot: ReviewSpot) {
        self.init(side: spot.side, start: spot.line, end: spot.line)
    }

    public init?(from: ReviewSpot, to: ReviewSpot) {
        guard from.side == to.side else { return nil }
        self.init(side: from.side, start: from.line, end: to.line)
    }

    public var span: Int { end - start + 1 }

    public var isRange: Bool { end > start }

    public var anchor: ReviewSpot { ReviewSpot(side: side, line: start) }

    public var spots: [ReviewSpot] {
        (start...end).map { ReviewSpot(side: side, line: $0) }
    }

    public func contains(_ spot: ReviewSpot) -> Bool {
        spot.side == side && spot.line >= start && spot.line <= end
    }
}

public extension DiffLine {
    var reviewSpot: ReviewSpot? {
        switch kind {
        case .deletion: oldNumber.map { ReviewSpot(side: .old, line: $0) }
        case .addition, .context: newNumber.map { ReviewSpot(side: .new, line: $0) }
        case .noNewline: nil
        }
    }
}

public enum ReviewCapture {
    public static func anchor(
        at selection: ReviewSelection,
        hunks: [DiffHunk],
        fileLines: [String]?
    ) -> ReviewCommentAnchor? {
        for hunk in hunks {
            if let anchor = ReviewCommentAnchor.make(
                line: selection.start, span: selection.span, side: selection.side, in: hunk
            ) {
                return anchor
            }
        }
        guard selection.side == .new, let fileLines,
              fileLines.indices.contains(selection.start - 1) else {
            return nil
        }
        return .make(line: selection.start, span: selection.span, in: fileLines)
    }

    public static func anchor(
        at spot: ReviewSpot,
        hunks: [DiffHunk],
        fileLines: [String]?
    ) -> ReviewCommentAnchor? {
        anchor(at: ReviewSelection(spot), hunks: hunks, fileLines: fileLines)
    }
}

public struct ReviewPlacement: Sendable, Hashable, Identifiable {
    public enum Status: Sendable, Hashable {
        case placed(ReviewSpot, moved: Bool)
        case hidden(line: Int)
        case outdated
    }

    public var comment: ReviewComment
    public var status: Status
    public var covered: [ReviewSpot]

    public var id: ReviewCommentID { comment.id }

    public var spot: ReviewSpot? {
        if case .placed(let spot, _) = status { return spot }
        return nil
    }

    public var band: ReviewSpot? { covered.last ?? spot }

    public init(comment: ReviewComment, status: Status, covered: [ReviewSpot]? = nil) {
        self.comment = comment
        self.status = status
        if let covered {
            self.covered = covered
        } else if case .placed(let spot, _) = status {
            self.covered = [spot]
        } else {
            self.covered = []
        }
    }
}

public enum ReviewPlacements {
    public static func place(
        _ comments: [ReviewComment],
        in file: FileDiff,
        currentLines: [String]?,
        revealedNewLines: [Int: String] = [:]
    ) -> [ReviewPlacement] {
        var oldLines: [Int: String] = [:]
        var newLines: [Int: String] = revealedNewLines
        for hunk in file.hunks {
            for line in hunk.lines where line.kind != .noNewline {
                if let number = line.oldNumber { oldLines[number] = line.text }
                if let number = line.newNumber { newLines[number] = line.text }
            }
        }

        return comments.sortedForReview().map { comment in
            let printed = comment.side == .old ? oldLines : newLines

            if comment.side == .new, let currentLines {
                let resolution = comment.anchor.resolve(in: currentLines)
                guard !resolution.isOutdated else {
                    return ReviewPlacement(comment: comment, status: .outdated)
                }
                if printed[resolution.line] == comment.anchor.text {
                    return ReviewPlacement(
                        comment: comment,
                        status: .placed(
                            ReviewSpot(side: .new, line: resolution.line),
                            moved: resolution.line != comment.anchor.line
                        ),
                        covered: covered(
                            from: resolution.line, span: comment.anchor.span,
                            side: .new, printed: printed
                        )
                    )
                }
                return ReviewPlacement(comment: comment, status: .hidden(line: resolution.line))
            }

            if printed[comment.anchor.line] == comment.anchor.text {
                return ReviewPlacement(
                    comment: comment,
                    status: .placed(
                        ReviewSpot(side: comment.side, line: comment.anchor.line), moved: false
                    ),
                    covered: covered(
                        from: comment.anchor.line, span: comment.anchor.span,
                        side: comment.side, printed: printed
                    )
                )
            }
            return ReviewPlacement(comment: comment, status: .outdated)
        }
    }

    private static func covered(
        from line: Int,
        span: Int,
        side: ReviewCommentSide,
        printed: [Int: String]
    ) -> [ReviewSpot] {
        var spots = [ReviewSpot(side: side, line: line)]
        guard span > 1 else { return spots }
        for number in (line + 1)..<(line + span) {
            guard printed[number] != nil else { break }
            spots.append(ReviewSpot(side: side, line: number))
        }
        return spots
    }
}
