import Foundation
import Core

@MainActor
struct CanvasCommentControls {
    var marks: [CanvasComment] = []
    var listed: [CanvasComment] = []
    var status: @MainActor (CanvasComment) -> CanvasCommentStatus = { CanvasCommentBoard.status(of: $0, wait: nil) }
    var add: @MainActor (CanvasPoint, String) -> Void = { _, _ in }
    var edit: @MainActor (CanvasCommentID, String) async -> Bool = { _, _ in true }
    var delete: @MainActor (CanvasCommentID) -> Void = { _ in }
    var resend: @MainActor (CanvasCommentID) -> Void = { _ in }
    var canSend: @MainActor (CanvasComment) -> Bool = { _ in false }
    var send: @MainActor (CanvasCommentID) -> Void = { _ in }

    static let none = CanvasCommentControls()
}

extension CanvasCommentControls {
    init(model: CanvasDocumentModel) {
        marks = model.commentMarks
        listed = model.listedComments
        status = { model.commentStatus(of: $0) }
        add = { point, text in Task { await model.addComment(at: point, text: text) } }
        edit = { id, text in await model.editQueued(id, text: text) }
        delete = { id in Task { await model.deleteQueued(id) } }
        resend = { id in Task { await model.resend(id) } }
        canSend = { model.canSendComment($0) }
        send = { id in Task { await model.sendCommentFromFile(id) } }
    }
}
