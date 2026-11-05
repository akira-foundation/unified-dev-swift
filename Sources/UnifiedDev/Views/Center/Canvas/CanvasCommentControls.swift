import Foundation
import Core

@MainActor
struct CanvasCommentControls {
    var marks: [CanvasComment] = []
    var listed: [CanvasComment] = []
    var unreadDeclined = 0
    var status: @MainActor (CanvasComment) -> CanvasCommentStatus = { CanvasCommentBoard.status(of: $0, wait: nil) }
    var add: @MainActor (CanvasPoint, String) -> Void = { _, _ in }
    var edit: @MainActor (CanvasCommentID, String) -> Void = { _, _ in }
    var delete: @MainActor (CanvasCommentID) -> Void = { _ in }
    var resend: @MainActor (CanvasCommentID) -> Void = { _ in }
    var markListRead: @MainActor () -> Void = {}

    static let none = CanvasCommentControls()
}

extension CanvasCommentControls {
    init(model: CanvasDocumentModel) {
        marks = model.commentMarks
        listed = model.listedComments
        unreadDeclined = model.unreadDeclinedComments.count
        status = { model.commentStatus(of: $0) }
        add = { point, text in Task { await model.addComment(at: point, text: text) } }
        edit = { id, text in Task { await model.editQueued(id, text: text) } }
        delete = { id in Task { await model.deleteQueued(id) } }
        resend = { id in Task { await model.resend(id) } }
        markListRead = { model.seenDeclinedComments.formUnion(model.unreadDeclinedComments.map(\.id)) }
    }
}
