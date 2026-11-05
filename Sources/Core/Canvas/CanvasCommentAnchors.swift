import Foundation

public enum CanvasCommentAnchors {
    public static func following(from old: CanvasDocument, to new: CanvasDocument) -> CanvasDocument {
        var followed = new
        for index in followed.comments.indices {
            guard let move = move(of: followed.comments[index], from: old, to: new) else { continue }
            followed.comments[index].anchor.x += move.x
            followed.comments[index].anchor.y += move.y
        }
        return followed
    }

    private static func move(of comment: CanvasComment, from old: CanvasDocument, to new: CanvasDocument) -> CanvasPoint? {
        if let id = comment.elementID,
           let before = old.elements.first(where: { $0.id == id }), let after = new.elements.first(where: { $0.id == id }) {
            return difference(
                from: CanvasHitTest.absoluteRect(of: before, in: old).origin,
                to: CanvasHitTest.absoluteRect(of: after, in: new).origin
            )
        }
        guard let id = comment.frameID,
              let before = old.frames.first(where: { $0.id == id }), let after = new.frames.first(where: { $0.id == id }) else { return nil }
        return difference(from: before.rect.origin, to: after.rect.origin)
    }

    private static func difference(from before: CanvasPoint, to after: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: after.x - before.x, y: after.y - before.y)
    }
}
