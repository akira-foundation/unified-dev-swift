import SwiftUI
import Core

enum CanvasPen {
    static let width = 6.0
    static let colour = "#111827"
    static let screenTolerance = 1.5
}

struct CanvasPenDraft {
    private(set) var points: [CanvasPoint] = []
    private(set) var wasReduced = false

    var isEmpty: Bool { points.isEmpty }

    mutating func append(_ point: CanvasPoint, tolerance: Double) {
        let before = points.count
        points = CanvasStrokeBuilder.appending(point, to: points, tolerance: tolerance)
        if points.count <= before { wasReduced = true }
    }

    var isReducedOnRelease: Bool {
        wasReduced || CanvasStrokeBuilder.isReducedOnRelease(rawCount: points.count)
    }
}

extension CanvasPenDraft {
    func element(in document: CanvasDocument, viewport: CanvasViewport) -> CanvasElement? {
        CanvasStrokeBuilder.element(
            drawing: points, width: CanvasPen.width, colour: CanvasPen.colour,
            tolerance: viewport.canvasLength(forScreen: CanvasPen.screenTolerance), in: document
        )
    }
}

struct CanvasPenPreview: View {
    let points: [CanvasPoint]
    let viewport: CanvasViewport

    var body: some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: screen(first))
            for next in points.dropFirst() { path.addLine(to: screen(next)) }
            if points.count == 1 { path.addLine(to: screen(first)) }
        }
        .stroke(
            Color(canvas: CanvasPen.colour),
            style: StrokeStyle(lineWidth: CanvasPen.width * viewport.zoom, lineCap: .round, lineJoin: .round)
        )
        .allowsHitTesting(false)
    }

    private func screen(_ point: CanvasPoint) -> CGPoint {
        let converted = viewport.toScreen(point)
        return CGPoint(x: converted.x, y: converted.y)
    }
}
