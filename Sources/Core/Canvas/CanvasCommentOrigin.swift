import Foundation

public enum CanvasCommentOrigin {
    public static func cameWithFile(_ comment: CanvasComment, addedThisRun: Set<CanvasCommentID>) -> Bool {
        comment.state == .queued && comment.deliveryID == nil && !addedThisRun.contains(comment.id)
    }
}
