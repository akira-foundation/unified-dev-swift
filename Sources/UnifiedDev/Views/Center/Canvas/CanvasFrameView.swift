import SwiftUI
import Core

struct CanvasFrameView: View {
    let frame: CanvasFrame
    let elements: [CanvasElement]
    let worktree: String
    let documentPath: String
    var renderedImages: CanvasRenderedImages?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(canvas: frame.fill)
            ForEach(elements) { element in
                CanvasElementView(element: element, worktree: worktree, documentPath: documentPath, renderedImages: renderedImages)
                    .offset(x: element.rect.origin.x, y: element.rect.origin.y)
            }
        }
        .frame(width: frame.rect.size.width, height: frame.rect.size.height, alignment: .topLeading)
        .clipped()
    }
}
