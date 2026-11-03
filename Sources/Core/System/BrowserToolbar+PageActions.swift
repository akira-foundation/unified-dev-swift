import Foundation

extension BrowserToolbar {
    public var openInDefaultBrowser: Control {
        Control(
            symbol: "arrow.up.forward.app",
            name: "Open in Default Browser",
            help: Self.help("Open this page in the browser the Mac opens links with", key: .browserOpenInDefaultBrowser),
            isEnabled: externalURL != nil
        )
    }

    public var externalURL: URL? {
        BrowserAddress.external(from: page.address)
    }

    public func comment(isReviewing: Bool, isSaving: Bool) -> Control {
        let isEnabled = !isSaving && (isReviewing || regionCapture.isEnabled)
        if isReviewing {
            return Control(
                symbol: "checkmark",
                name: "Done",
                help: Self.help("Finish reviewing this page", key: .browserComment),
                isEnabled: isEnabled,
                isActive: isEnabled
            )
        }
        return Control(
            symbol: "text.bubble",
            name: "Comment",
            help: Self.help("Drag over part of this page to leave a comment", key: .browserComment),
            isEnabled: isEnabled
        )
    }

    public static func viewport(_ viewport: BrowserViewport) -> Control {
        Control(
            symbol: "ipad.and.iphone",
            name: "Responsive Preview",
            help: Self.help(
                viewport.isEnabled
                    ? "Viewport: \(viewport.width) × \(viewport.height). Show size controls or restore full size"
                    : "Preview at phone, tablet and desktop sizes",
                key: .browserResponsivePreview
            ),
            isEnabled: true,
            isActive: viewport.isEnabled
        )
    }

    public static func fullSize(_ viewport: BrowserViewport) -> Control {
        Control(
            symbol: "arrow.up.left.and.arrow.down.right",
            name: "Full size",
            help: Self.help("Restore the page to the full browser pane", key: .browserFullSize),
            isEnabled: viewport.isEnabled
        )
    }
}
