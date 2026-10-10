import Foundation
import Testing
@testable import Core

@Suite("Ordering review comments")
struct ReviewCommentOrderTests {
    @Test("comments that tie on file and line are still ordered, whatever ids they drew")
    func tiesAreBrokenWithoutTheId() {
        let made = Date(timeIntervalSince1970: 1_000)
        func comment(side: ReviewCommentSide, span: Int) -> ReviewComment {
            ReviewComment(
                workspaceID: WorkspaceID("w"), filePath: "a/Widget.swift", side: side,
                anchor: ReviewCommentAnchor(line: 34, text: "x", span: span), body: "b",
                createdAt: made
            )
        }
        let narrow = comment(side: .new, span: 1)
        let wide = comment(side: .new, span: 5)
        let removed = comment(side: .old, span: 5)

        for attempt in 0..<40 {
            let shuffled = attempt.isMultiple(of: 2)
                ? [wide, removed, narrow]
                : [narrow, wide, removed]
            let marks = shuffled.sortedForReview().map(ReviewCommentSummary.mark(for:))

            #expect(marks == ["-34…38", "+34", "+34…38"], "attempt \(attempt)")
        }
    }
}
