import SwiftUI
import Core

struct CanvasSelectionBox: Hashable {
    var rect: CanvasRect
    var rotation: Double
}

struct CanvasSelectionOverlay: View {
    static let space = "canvas"
    private static let handleSize = 10.0

    let viewport: CanvasViewport
    let boxes: [CanvasSelectionBox]
    let guides: [CanvasGuide]
    let showsHandles: Bool
    let onResize: (CanvasResizeHandle, CGSize, Bool) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                let screen = screenRect(box.rect)
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: screen.width, height: screen.height)
                    .rotationEffect(.degrees(box.rotation))
                    .offset(x: screen.minX, y: screen.minY)
                    .allowsHitTesting(false)
            }
            ForEach(Array(guides.enumerated()), id: \.offset) { _, guide in
                guideLine(guide)
                    .stroke(Color.pink, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            if showsHandles, let box = boxes.first {
                ForEach(CanvasResizeHandle.allCases, id: \.self) { handle in
                    handleView(handle, of: box)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func screenRect(_ rect: CanvasRect) -> CGRect {
        let origin = viewport.toScreen(rect.origin)
        return CGRect(
            x: origin.x, y: origin.y,
            width: rect.size.width * viewport.zoom, height: rect.size.height * viewport.zoom
        )
    }

    private func guideLine(_ guide: CanvasGuide) -> Path {
        var path = Path()
        switch guide.axis {
        case .vertical:
            let top = viewport.toScreen(CanvasPoint(x: guide.position, y: guide.from))
            let bottom = viewport.toScreen(CanvasPoint(x: guide.position, y: guide.to))
            path.move(to: CGPoint(x: top.x, y: top.y))
            path.addLine(to: CGPoint(x: bottom.x, y: bottom.y))
        case .horizontal:
            let leading = viewport.toScreen(CanvasPoint(x: guide.from, y: guide.position))
            let trailing = viewport.toScreen(CanvasPoint(x: guide.to, y: guide.position))
            path.move(to: CGPoint(x: leading.x, y: leading.y))
            path.addLine(to: CGPoint(x: trailing.x, y: trailing.y))
        }
        return path
    }

    private func handleView(_ handle: CanvasResizeHandle, of box: CanvasSelectionBox) -> some View {
        let point = viewport.toScreen(CanvasResize.handlePoint(handle, of: box.rect, rotation: box.rotation))
        let anchor = CGPoint(x: point.x, y: point.y)
        return Circle()
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: Self.handleSize, height: Self.handleSize)
            .contentShape(Rectangle().inset(by: -4))
            .offset(x: anchor.x - Self.handleSize / 2, y: anchor.y - Self.handleSize / 2)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { onResize(handle, $0.translation, false) }
                    .onEnded { onResize(handle, $0.translation, true) }
            )
    }
}
