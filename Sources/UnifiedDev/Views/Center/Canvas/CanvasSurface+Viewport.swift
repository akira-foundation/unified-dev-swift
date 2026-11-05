import SwiftUI
import Core

extension CanvasSurface {
    var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? viewport
                zoomStart = start
                var next = start
                next.zoom(by: value.magnification, around: CanvasPoint(x: value.startLocation.x, y: value.startLocation.y))
                viewport = next
            }
            .onEnded { _ in zoomStart = nil }
    }

    func zoom(by factor: Double) {
        viewport.zoom(by: factor, around: CanvasPoint(x: size.width / 2, y: size.height / 2))
    }

    func fit(in available: CGSize) {
        guard let bounds = bounds else { return }
        viewport = CanvasViewport.fitting(bounds, in: CanvasSize(width: available.width, height: available.height))
    }

    var bounds: CanvasRect? {
        CanvasRect.union(of: document.frames.map(\.rect))
    }
}
