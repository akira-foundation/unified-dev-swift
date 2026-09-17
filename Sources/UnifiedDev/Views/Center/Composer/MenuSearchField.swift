import SwiftUI
import AppKit
import Core

struct MenuSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onKey: @MainActor (ComposerKey) -> Bool
    var onHorizontal: (@MainActor (Int) -> Bool)?
    var font: NSFont?
    var onBacktab: (@MainActor () -> Bool)?
    var onDeleteEmpty: (@MainActor () -> Bool)?
    var onRight: (@MainActor (Bool) -> Bool)?
    var selectAllToken = 0

    func makeNSView(context: Context) -> NSTextField {
        let field = MenuSearchFieldView()
        field.onCommandReturn = { [weak coordinator = context.coordinator] in
            coordinator?.onKey(.commandReturn) ?? false
        }
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.stringValue = text
        context.coordinator.takeFocus(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.onKey = onKey
        context.coordinator.onHorizontal = onHorizontal
        context.coordinator.onBacktab = onBacktab
        context.coordinator.onDeleteEmpty = onDeleteEmpty
        context.coordinator.onRight = onRight
        context.coordinator.text = $text
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
        if field.stringValue != text { field.stringValue = text }
        let resolved = font ?? .systemFont(ofSize: NSFont.systemFontSize)
        if field.font != resolved { field.font = resolved }
        context.coordinator.selectAll(field, token: selectAllToken)
        context.coordinator.takeFocus(field)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onKey: onKey, onHorizontal: onHorizontal)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onKey: @MainActor (ComposerKey) -> Bool
        var onHorizontal: (@MainActor (Int) -> Bool)?
        var onBacktab: (@MainActor () -> Bool)?
        var onDeleteEmpty: (@MainActor () -> Bool)?
        var onRight: (@MainActor (Bool) -> Bool)?
        private var selectedToken = 0
        private var didFocus = false

        init(
            text: Binding<String>,
            onKey: @escaping @MainActor (ComposerKey) -> Bool,
            onHorizontal: (@MainActor (Int) -> Bool)?
        ) {
            self.text = text
            self.onKey = onKey
            self.onHorizontal = onHorizontal
        }

        @MainActor
        func takeFocus(_ field: NSTextField) {
            guard !didFocus else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.didFocus, let window = field.window,
                      AutomaticFocus.mayUpdateResponder(applicationIsActive: NSApp.isActive,
                                                        windowIsKey: window.isKeyWindow,
                                                        windowIsVisible: window.isVisible) else { return }
                didFocus = window.makeFirstResponder(field)
            }
        }

        @MainActor
        func selectAll(_ field: NSTextField, token: Int) {
            guard token != selectedToken else { return }
            selectedToken = token
            guard field.window?.firstResponder === field.currentEditor() else { return }
            field.selectText(nil)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(
            _ control: NSControl, textView: NSTextView, doCommandBy selector: Selector
        ) -> Bool {
            if let onHorizontal {
                switch selector {
                case #selector(NSResponder.moveLeft(_:)): if onHorizontal(-1) { return true }
                case #selector(NSResponder.moveRight(_:)): if onHorizontal(1) { return true }
                default: break
                }
            }
            if let onRight, selector == #selector(NSResponder.moveRight(_:)) {
                let selection = textView.selectedRange()
                let atEnd = selection.length == 0
                    && selection.location == (textView.string as NSString).length
                if onRight(atEnd) { return true }
            }
            if let onBacktab, selector == #selector(NSResponder.insertBacktab(_:)) {
                if onBacktab() { return true }
            }
            if let onDeleteEmpty, selector == #selector(NSResponder.deleteBackward(_:)),
               textView.string.isEmpty {
                if onDeleteEmpty() { return true }
            }
            let key: ComposerKey? = switch selector {
            case #selector(NSResponder.moveUp(_:)): .up
            case #selector(NSResponder.moveDown(_:)): .down
            case #selector(NSResponder.insertNewline(_:)): .returnKey
            case #selector(NSResponder.cancelOperation(_:)): .escape
            case #selector(NSResponder.insertTab(_:)): .tab
            default: nil
            }
            guard let key else { return false }
            return onKey(key)
        }
    }
}

final class MenuSearchFieldView: NSTextField {
    var onCommandReturn: (@MainActor () -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])
        guard modifiers == .command,
              let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first,
              Int(scalar.value) == 0x0D,
              window?.firstResponder === currentEditor(),
              let onCommandReturn else {
            return super.performKeyEquivalent(with: event)
        }
        return onCommandReturn() ? true : super.performKeyEquivalent(with: event)
    }
}
