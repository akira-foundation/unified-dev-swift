import SwiftUI
import Core

struct ReviewCommentSnapshotGallery: View {
    private static let sheet: CGFloat = 760

    @State private var edited = "This retries for ever. Give it a ceiling.\n"
        + "Three attempts, then let the job fail so the queue can see it."
    @State private var written = "The webhook signature is computed over the raw body.\n"
        + "Serialising and re-encoding here changes it."

    private static func comment(_ body: String, line: Int = 179, span: Int = 1) -> ReviewComment {
        ReviewComment(
            workspaceID: WorkspaceID("w1"),
            filePath: "src/Jobs/CallWebhookJob.php",
            side: .new,
            anchor: ReviewCommentAnchor(
                line: line,
                text: "        $this->release($this->backoff());",
                before: ["    {", ""],
                after: ["    }", ""],
                span: span
            ),
            body: body
        )
    }

    private static func placement(
        _ body: String,
        line: Int = 179,
        span: Int = 1
    ) -> ReviewPlacement {
        ReviewPlacement(
            comment: comment(body, line: line, span: span),
            status: .placed(ReviewSpot(side: .new, line: line), moved: false),
            covered: (line..<(line + span)).map { ReviewSpot(side: .new, line: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("At rest") {
                ReviewCommentBandView(
                    placement: Self.placement("This retries for ever."),
                    width: Self.sheet,
                    onBeginEdit: {}, onCommitEdit: {}, onCancelEdit: {}, onRemove: {}
                )
            }

            group("Under the pointer") {
                ReviewCommentBandView(
                    placement: Self.placement("This retries for ever."),
                    width: Self.sheet,
                    isHovered: true,
                    onBeginEdit: {}, onCommitEdit: {}, onCancelEdit: {}, onRemove: {}
                )
            }

            group("Being rewritten, across two lines") {
                ReviewCommentBandView(
                    placement: Self.placement("This retries for ever."),
                    width: Self.sheet,
                    editing: $edited,
                    onBeginEdit: {}, onCommitEdit: {}, onCancelEdit: {}, onRemove: {}
                )
            }

            group("After the edit") {
                ReviewCommentBandView(
                    placement: Self.placement(edited),
                    width: Self.sheet,
                    onBeginEdit: {}, onCommitEdit: {}, onCancelEdit: {}, onRemove: {}
                )
            }

            group("Left across a range of lines") {
                ReviewCommentBandView(
                    placement: Self.placement("These five are one function.", span: 5),
                    width: Self.sheet,
                    onBeginEdit: {}, onCommitEdit: {}, onCancelEdit: {}, onRemove: {}
                )
            }

            group("A range whose lines are gone") {
                ReviewCommentBandView(
                    placement: ReviewPlacement(
                        comment: Self.comment("These five are one function.", span: 5),
                        status: .outdated
                    ),
                    width: Self.sheet,
                    onBeginEdit: {}, onCommitEdit: {}, onCancelEdit: {}, onRemove: {}
                )
            }

            group("A new comment, written across two lines") {
                ReviewCommentEditorView(
                    text: $written,
                    width: Self.sheet,
                    onCommit: {},
                    onCancel: {}
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }
}

extension Gallery {
    static let reviewComments = Gallery(
        name: "review-comments",
        title: "Review comments",
        size: CGSize(width: 820, height: 1_100),
        needsFocus: true,
        view: { _ in AnyView(ReviewCommentSnapshotGallery()) }
    )
}
