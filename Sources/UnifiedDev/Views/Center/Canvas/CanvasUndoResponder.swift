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

    func makeNSView(context: Context) -> CanvasUndoResponderView {
        let view = CanvasUndoResponderView()
        view.canvasUndo = manager
        focus.view = view
        return view
    }

    func updateNSView(_ view: CanvasUndoResponderView, context: Context) {
        view.canvasUndo = manager
        focus.view = view
    }
}

final class CanvasUndoResponderView: NSView, NSMenuItemValidation {
    var canvasUndo: UndoManager?

    override var acceptsFirstResponder: Bool { canvasUndo != nil }

    override var undoManager: UndoManager? { canvasUndo }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @objc func undo(_ sender: Any?) {
        canvasUndo?.undo()
    }

    @objc func redo(_ sender: Any?) {
        canvasUndo?.redo()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let canvasUndo else { return false }
        switch menuItem.action {
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
