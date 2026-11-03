import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Core

struct CanvasTextEditorOverlay: View {
    let editing: CanvasTextEditing
    let document: CanvasDocument
    let viewport: CanvasViewport
    let finish: () -> Void

    var body: some View {
        if let element = document.elements.first(where: { $0.id == editing.elementID }) {
            let rect = CanvasHitTest.absoluteRect(of: element, in: document)
            let origin = viewport.toScreen(rect.origin)
            let inset = element.isNote ? 12.0 : 0
            ZStack(alignment: .topLeading) {
                if element.isNote {
                    RoundedRectangle(cornerRadius: element.style.cornerRadius)
                        .fill(Color(canvas: element.style.fill ?? "#FFE98A"))
                }
                CanvasTextEditor(
                    editing: editing,
                    width: rect.size.width - inset * 2,
                    height: rect.size.height - inset * 2,
                    finish: finish
                )
                .frame(width: rect.size.width - inset * 2, height: rect.size.height - inset * 2)
                .padding(inset)
            }
            .frame(width: rect.size.width, height: rect.size.height)
            .rotationEffect(.degrees(element.style.rotation))
            .scaleEffect(viewport.zoom, anchor: .topLeading)
            .frame(width: 0, height: 0, alignment: .topLeading)
            .offset(x: origin.x, y: origin.y)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

extension CanvasSurface {
    static func text(of element: CanvasElement) -> CanvasText? {
        switch element.kind {
        case .text(let text), .note(let text): text
        default: nil
        }
    }

    static func operations(finishing editing: CanvasTextEditing, in document: CanvasDocument) -> [CanvasOperation] {
        guard editing.text != editing.original,
              let element = document.elements.first(where: { $0.id == editing.elementID }) else { return [] }
        let padding = element.isNote ? 24.0 : 0
        let measured = CanvasTextMeasure.size(of: editing.text, width: element.rect.size.width - padding, padding: padding)
        var rect = element.rect
        rect.size.height = max(rect.size.height, measured.height)
        return [.updateElement(
            element.id,
            expectedRevision: nil,
            CanvasElementPatch(rect: rect, kind: element.isNote ? .note(editing.text) : .text(editing.text))
        )]
    }

    static func editableElement(at point: CanvasPoint, in document: CanvasDocument) -> (element: CanvasElement, text: CanvasText)? {
        guard let id = CanvasHitTest.element(at: point, in: document),
              let element = document.elements.first(where: { $0.id == id }),
              let text = text(of: element) else { return nil }
        return (element, text)
    }

    static func newText(at point: CanvasPoint, in document: CanvasDocument) -> CanvasElement? {
        guard let frame = frame(containing: point, in: document) else { return nil }
        let x = point.x - frame.rect.origin.x
        let y = point.y - frame.rect.origin.y
        let run = CanvasTextRun(text: "", fontName: "Helvetica Neue", size: 64, weight: 0, colour: "#111827")
        return CanvasElement(
            frameID: frame.id,
            rect: CanvasRect(x: x, y: y, width: max(200, min(640, frame.rect.size.width - x)), height: 96),
            kind: .text(CanvasText(runs: [run]))
        )
    }

    static func frame(containing point: CanvasPoint, in document: CanvasDocument) -> CanvasFrame? {
        document.frames.last { frame in
            point.x >= frame.rect.origin.x && point.x <= frame.rect.origin.x + frame.rect.size.width
                && point.y >= frame.rect.origin.y && point.y <= frame.rect.origin.y + frame.rect.size.height
        }
    }

    static func chooseImageFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

extension CanvasElement {
    var isNote: Bool {
        if case .note = kind { true } else { false }
    }
}
