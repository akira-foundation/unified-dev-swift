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
            let inset = CanvasEditing.notePadding(of: element) / 2
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
    static func chooseImageFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
