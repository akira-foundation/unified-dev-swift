import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> WindowReadingView {
        let view = WindowReadingView()
        view.onWindowChange = { window = $0 }
        return view
    }

    func updateNSView(_ nsView: WindowReadingView, context: Context) {
        nsView.onWindowChange = { window = $0 }
        nsView.reportWindow()
    }

    final class WindowReadingView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        private weak var reported: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportWindow()
        }

        func reportWindow() {
            guard reported !== window else { return }
            reported = window
            onWindowChange?(window)
        }
    }
}
