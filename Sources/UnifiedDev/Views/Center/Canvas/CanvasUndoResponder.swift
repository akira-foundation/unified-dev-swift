import AppKit
import SwiftUI
import Core

@MainActor
final class CanvasUndoFocus {
    weak var view: CanvasUndoResponderView?

    func take() {
        guard let view, let window = view.window, window.firstResponder !== view else { return }
        window.makeFirstResponder(view)
    }

    func returnAfterEditing() {
        guard let window = view?.window, CanvasEditing.returnsFocus(from: Self.holder(in: window)) else { return }
        take()
    }

    private static func holder(in window: NSWindow) -> CanvasFocusHolder {
        guard let responder = window.firstResponder, responder !== window else { return .nothing }
        return responder is CanvasEditingTextView ? .closingEditor : .somethingElse
    }
}

struct CanvasUndoResponder: NSViewRepresentable {
    let manager: UndoManager?
    let focus: CanvasUndoFocus
    let canDelete: Bool
    let delete: () -> Void

    func makeNSView(context: Context) -> CanvasUndoResponderView {
        let view = CanvasUndoResponderView()
        update(view)
        return view
    }

    func updateNSView(_ view: CanvasUndoResponderView, context: Context) {
        update(view)
    }

    private func update(_ view: CanvasUndoResponderView) {
        view.canvasUndo = manager
        view.canDeleteSelection = canDelete
        view.deleteSelection = delete
        focus.view = view
    }
}

final class CanvasUndoResponderView: NSView, NSMenuItemValidation {
    var canvasUndo: UndoManager?
    var canDeleteSelection = false
    var deleteSelection: () -> Void = {}

    override var acceptsFirstResponder: Bool { canvasUndo != nil }

    override var undoManager: UndoManager? { canvasUndo }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @objc func undo(_ sender: Any?) {
        canvasUndo?.undo()
    }

    @objc func redo(_ sender: Any?) {
        canvasUndo?.redo()
    }

    @objc func delete(_ sender: Any?) {
        deleteSelection()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard canDeleteSelection, modifiers.isEmpty, CanvasSelection.isDeleteKey(event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        deleteSelection()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let canvasUndo else { return false }
        switch menuItem.action {
        case #selector(delete(_:)):
            return canDeleteSelection
        case #selector(undo(_:)):
            menuItem.title = canvasUndo.undoMenuItemTitle
            return canvasUndo.canUndo
        case #selector(redo(_:)):
            menuItem.title = canvasUndo.redoMenuItemTitle
            return canvasUndo.canRedo
        default:
            return false
        }
    }
}
