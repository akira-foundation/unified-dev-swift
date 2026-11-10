import AppKit
import Core
import SwiftUI

final class MarkdownChromeHost: NSHostingView<AnyView> {
    var controls: CGRect = .null
    var selectableText: CGRect = .null

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        let local = convert(point, from: superview)
        return MarkdownChromeHit.keeps(hitIsHost: hit === self, point: local, controls: controls) ? hit : nil
    }
}
