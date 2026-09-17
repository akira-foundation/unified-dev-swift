import SwiftUI
import Core

struct PendingDeleteSnapshotGallery: View {
    private static let bubble: CGFloat = 520

    @State private var bubbleWidth: TranscriptBubbleWidth = {
        let width = TranscriptBubbleWidth()
        width.cap = bubble
        return width
    }()

    private static func delivery(_ body: String) -> Delivery {
        Delivery(targetSessionID: SessionID("s1"), body: body)
    }

    private static let typed = "sdfsd\nsdfsdf"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("At rest") {
                PendingTurnRowView(
                    delivery: Self.delivery(Self.typed),
                    holdSentence: DeliveryHold.question.sentence(on: .claudeCode),
                    onEdit: {},
                    onDelete: {}
                )
            }

            group("Under the pointer") {
                PendingTurnRowView(
                    delivery: Self.delivery(Self.typed),
                    holdSentence: DeliveryHold.question.sentence(on: .claudeCode),
                    onEdit: {},
                    onDelete: {},
                    pointerInside: true
                )
            }

            group("Three waiting, one sentence") {
                VStack(spacing: 0) {
                    PendingTurnRowView(
                        delivery: Self.delivery("Also check the migration."),
                        holdSentence: nil,
                        onEdit: {},
                        onDelete: {}
                    )
                    PendingTurnRowView(
                        delivery: Self.delivery(Self.typed),
                        holdSentence: nil,
                        onEdit: {},
                        onDelete: {},
                        pointerInside: true
                    )
                    PendingTurnRowView(
                        delivery: Self.delivery("And run the tests when you are done."),
                        holdSentence: DeliveryHold.setup.sentence(on: .claudeCode),
                        onEdit: {},
                        onDelete: {}
                    )
                }
            }

            group("A pending message carrying a file pill") {
                PendingTurnRowView(
                    delivery: Self.delivery(
                        "Look at this \(AttachmentDraft.token(for: ".unifieddev/attachments/2UCGb6/shot.png"))"
                    ),
                    holdSentence: DeliveryHold.setup.sentence(on: .claudeCode),
                    onEdit: {},
                    onDelete: {},
                    pointerInside: true
                )
            }

            group("The question, when the composer is empty") {
                sheet(for: .toComposer(Self.typed))
            }

            group("The question, when the composer is not") {
                sheet(for: .discarded(.composerInUse))
            }

            group("After Delete, when the message had already gone") {
                NoticeBanner(
                    notice: Notice(message: PendingMessageDiscard.alreadySentSentence),
                    onDismiss: {}
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.transcriptBubbleWidth, bubbleWidth)
    }

    private func sheet(for recovery: PendingMessageDiscard.Recovery) -> some View {
        let question = PendingMessageDiscard.question(for: recovery)
        return ConfirmationSheet(
            confirmation: Confirmation(
                title: question.title,
                message: question.message,
                confirmLabel: question.confirmLabel,
                cancelLabel: question.cancelLabel
            ),
            onConfirm: {},
            onCancel: {}
        )
        .fixedSize()
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
    static let pendingDelete = Gallery(
        name: "pending-delete",
        title: "Pending message delete",
        size: CGSize(width: 820, height: 900),
        needsFocus: false,
        view: { app in AnyView(PendingDeleteSnapshotGallery().environment(app)) }
    )
}
