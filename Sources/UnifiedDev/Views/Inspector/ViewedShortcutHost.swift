import SwiftUI
import AppKit
import Core

struct ViewedShortcutHost: NSViewRepresentable {
    var hasFile: Bool
    var onToggle: () -> Void

    func makeNSView(context: Context) -> ViewedShortcutHostView {
        ViewedShortcutHostView()
    }

    func updateNSView(_ view: ViewedShortcutHostView, context: Context) {
        view.hasFile = hasFile
        view.onToggle = onToggle
    }
}

final class ViewedShortcutHostView: NSView {
    var hasFile = false
    var onToggle: () -> Void = {}

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override var acceptsFirstResponder: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard Self.isViewedShortcut(event) else { return false }
        guard ReviewViewedShortcut.isArmed(hasFile: hasFile, isTakingText: isTakingText) else {
            return false
        }
        onToggle()
        return true
    }

    static func isViewedShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])
        guard modifiers == .option else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "v"
    }

    private var isTakingText: Bool {
        guard let responder = window?.firstResponder else { return false }
        return responder is NSTextInputClient
    }
}
