import Foundation

extension BrowserToolbar {
    public func comment(isReviewing: Bool, isSaving: Bool) -> Control {
        let isEnabled = !isSaving && (isReviewing || regionCapture.isEnabled)
        if isReviewing {
            return Control(
                symbol: "checkmark",
                name: "Done",
                help: "Finish reviewing this page",
                isEnabled: isEnabled,
                isActive: isEnabled
            )
        }
        return Control(
            symbol: "text.bubble",
            name: "Comment",
            help: "Drag over part of this page to leave a comment",
            isEnabled: isEnabled
        )
    }

    public static func viewport(_ viewport: BrowserViewport) -> Control {
        Control(
            symbol: "ipad.and.iphone",
            name: "Responsive Preview",
            help: viewport.isEnabled
                ? "Viewport: \(viewport.width) × \(viewport.height). Show size controls or restore full size"
                : "Preview at phone, tablet and desktop sizes",
            isEnabled: true,
            isActive: viewport.isEnabled
        )
    }

    public static func fullSize(_ viewport: BrowserViewport) -> Control {
        Control(
            symbol: "arrow.up.left.and.arrow.down.right",
            name: "Full size",
            help: "Restore the page to the full browser pane",
            isEnabled: viewport.isEnabled
        )
    }
}
