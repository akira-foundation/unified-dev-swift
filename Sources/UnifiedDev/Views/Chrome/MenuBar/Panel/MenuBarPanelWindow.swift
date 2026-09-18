import AppKit
import Core

final class MenuBarPanelWindow: NSPanel {
    var onCommand: (MenuBarPanelKey.Command) -> Void = { _ in }

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: MenuBarPanelPlacement.width, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCommand(.close)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let command = Self.command(for: event) else { return super.performKeyEquivalent(with: event) }
        onCommand(command)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard let command = Self.command(for: event) else {
            super.keyDown(with: event)
            return
        }
        onCommand(command)
    }

    private static func command(for event: NSEvent) -> MenuBarPanelKey.Command? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: MenuShortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return MenuBarPanelKey.command(characters: event.charactersIgnoringModifiers ?? "", modifiers: modifiers)
    }
}
