import SwiftUI
import AppKit
import Core

struct MenuKeyHost: NSViewRepresentable {
    var onKey: @MainActor (ComposerKey) -> Bool

    func makeNSView(context: Context) -> MenuKeyHostView {
        let view = MenuKeyHostView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ view: MenuKeyHostView, context: Context) {
        view.onKey = onKey
        view.takeFocus()
    }
}

final class MenuKeyHostView: NSView {
    var onKey: @MainActor (ComposerKey) -> Bool = { _ in false }

    private var didFocus = false

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        takeFocus()
    }

    func takeFocus() {
        guard !didFocus, let window,
              AutomaticFocus.mayUpdateResponder(applicationIsActive: NSApp.isActive,
                                                windowIsKey: window.isKeyWindow,
                                                windowIsVisible: window.isVisible) else { return }
        didFocus = window.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if let key = Self.key(for: event), onKey(key) { return }
        super.keyDown(with: event)
    }

    static func key(for event: NSEvent) -> ComposerKey? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])

        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else {
            return nil
        }

        if modifiers == .command, Int(scalar.value) == 0x0D { return .commandReturn }
        guard modifiers.isEmpty else { return nil }

        switch Int(scalar.value) {
        case NSUpArrowFunctionKey: return .up
        case NSDownArrowFunctionKey: return .down
        case 0x0D, 0x03: return .returnKey
        case 0x1B: return .escape
        case 0x09: return .tab
        default: return nil
        }
    }
}
