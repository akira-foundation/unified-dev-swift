import AppKit
import SwiftUI

struct ArchiveInteractionShield: NSViewRepresentable {
    func makeNSView(context: Context) -> Shield { Shield() }
    func updateNSView(_ view: Shield, context: Context) {}

    final class Shield: NSView {
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }
        override func keyDown(with event: NSEvent) {}
        override func mouseDown(with event: NSEvent) {}
        override func rightMouseDown(with event: NSEvent) {}
    }
}
