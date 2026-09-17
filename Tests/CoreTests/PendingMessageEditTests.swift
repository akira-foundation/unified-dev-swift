import Testing
import Foundation
@testable import Core

@Suite("Editing a pending message")
struct PendingMessageEditTests {
    private func delivery(_ body: String, delivered: Bool = false) -> Delivery {
        Delivery(
            targetSessionID: SessionID("s"),
            body: body,
            deliveredAt: delivered ? Date() : nil
        )
    }

    @Test("an empty composer gets the words alone")
    func emptyComposerTakesTheWords() {
        #expect(PendingMessageEdit.draft(taking: delivery("one"), into: "") == "one")
    }

    @Test("a blank composer counts as empty, and its whitespace does not survive")
    func blankComposerTakesTheWords() {
        #expect(PendingMessageEdit.draft(taking: delivery("one"), into: " \n\n ") == "one")
    }

    @Test("the words go in front of what is already there, with a blank line between")
    func textComposerIsPrepended() {
        let joined = PendingMessageEdit.draft(taking: delivery("one"), into: "half a thought")
        #expect(joined == "one\n\nhalf a thought")
    }

    @Test("a multi-line message keeps its own newlines")
    func multiLineBodySurvives() {
        let joined = PendingMessageEdit.draft(taking: delivery("one\ntwo"), into: "three")
        #expect(joined == "one\ntwo\n\nthree")
    }

    @Test("offered for a message still in the queue")
    func pendingPlainTextIsEditable() {
        #expect(PendingMessageEdit.canEdit(delivery("one")))
    }

    @Test("not offered for a message that has gone")
    func deliveredIsNotEditable() {
        #expect(!PendingMessageEdit.canEdit(delivery("one", delivered: true)))
    }

    @Test("not offered for a message with attached files")
    func attachmentsAreNotEditable() {
        let body = AttachmentTrailer.compose(text: "look at this", paths: ["/tmp/shot.png"])
        #expect(!PendingMessageEdit.canEdit(delivery(body)))
    }

    @Test("not offered for a message carrying review comments")
    func reviewTurnsAreNotEditable() {
        let comment = ReviewComment(
            id: ReviewCommentID("Sources/Widget.swift#3#new"),
            workspaceID: WorkspaceID("w"),
            filePath: "Sources/Widget.swift",
            side: .new,
            anchor: ReviewCommentAnchor.make(line: 1, in: ["struct Widget {}"]),
            body: "rename this",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let body = ReviewTurn.compose(
            message: "Fix this.",
            comments: [comment],
            worktreePath: nil,
            template: PromptRegistry.definition(for: .review).defaultTemplate
        )
        #expect(!PendingMessageEdit.canEdit(delivery(body)))
    }

    @Test("edit hands the words back where delete would not")
    func editDisagreesWithDiscardOnPurpose() {
        let one = delivery("one")
        #expect(
            PendingMessageDiscard.recovery(of: one, composerDraft: "half a thought")
                == .discarded(.composerInUse)
        )
        #expect(PendingMessageEdit.draft(taking: one, into: "half a thought") == "one\n\nhalf a thought")
    }
}
