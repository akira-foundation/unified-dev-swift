import AppKit
import Core

extension NSScrollView {
    var endOffset: CGFloat {
        CGFloat(TranscriptAnchor.end(
            contentHeight: Double(documentView?.frame.height ?? 0),
            viewportHeight: Double(contentView.bounds.height)
        ))
    }

    var distanceFromEnd: CGFloat {
        max(0, endOffset - contentView.bounds.origin.y)
    }

    var isAtEnd: Bool {
        TranscriptAnchor.isAtEnd(
            offset: Double(contentView.bounds.origin.y),
            contentHeight: Double(documentView?.frame.height ?? 0),
            viewportHeight: Double(contentView.bounds.height)
        )
    }
}
