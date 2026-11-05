import SwiftUI
import Core

extension CanvasStage {
    func beginTextEditing(_ element: CanvasElement, text: CanvasText) {
        startEditing(element.id, text)
        selection = [element.id]
    }

    func doubleClick(at location: CGPoint) {
        guard tool == .select || tool == .text else { return }
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        guard let id = CanvasHitTest.element(at: point, in: document),
              let element = document.elements.first(where: { $0.id == id }),
              let text = element.text else { return }
        tool = .select
        beginTextEditing(element, text: text)
    }

    func placeText(at location: CGPoint) {
        let point = viewport.toCanvas(CanvasPoint(x: location.x, y: location.y))
        if let id = CanvasHitTest.element(at: point, in: document),
           let existing = document.elements.first(where: { $0.id == id }),
           let text = existing.text {
            tool = .select
            beginTextEditing(existing, text: text)
            return
        }
        let element = CanvasEditing.newText(at: point, in: document)
        guard let text = element.text else { return }
        apply([.addElement(element)])
        tool = .select
        beginTextEditing(element, text: text)
    }

    func placeNote(at location: CGPoint) {
        let element = CanvasEditing.newNote(at: canvasPoint(location), in: document)
        guard let text = element.text else { return }
        apply([.addElement(element)])
        tool = .select
        beginTextEditing(element, text: text)
    }
}
