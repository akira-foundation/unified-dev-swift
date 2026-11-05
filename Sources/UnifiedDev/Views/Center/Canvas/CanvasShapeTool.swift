import SwiftUI
import Core

struct CanvasShapeDraft: Equatable {
    var kind: CanvasShape.Kind
    var start: CanvasPoint
    var end: CanvasPoint
}

extension CanvasShape.Kind {
    var title: String {
        switch self {
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .line: "Line"
        case .arrow: "Arrow"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: "square"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        }
    }
}

struct CanvasShapePreview: View {
    let draft: CanvasShapeDraft
    let document: CanvasDocument
    let viewport: CanvasViewport

    var body: some View {
        let element = CanvasEditing.newShape(draft.kind, from: draft.start, to: draft.end, in: document)
        let origin = viewport.toScreen(CanvasHitTest.absoluteRect(of: element, in: document).origin)
        CanvasElementView(element: element, worktree: "", documentPath: "")
            .scaleEffect(viewport.zoom, anchor: .topLeading)
            .frame(width: 0, height: 0, alignment: .topLeading)
            .offset(x: origin.x, y: origin.y)
            .opacity(0.8)
            .allowsHitTesting(false)
    }
}
