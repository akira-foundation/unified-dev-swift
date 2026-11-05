import SwiftUI
import Core

enum CanvasPen {
    static let width = 6.0
    static let colour = "#111827"
    static let screenTolerance = 1.5
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

struct CanvasPenLimitNotice: View {
    let notice: CanvasNotice

    var body: some View {
        VStack(spacing: Metrics.spacingHair) {
            Text(verbatim: notice.title).font(Typo.labelEmphasis).foregroundStyle(Palette.textPrimary)
            ForEach(notice.lines, id: \.self) { line in
                Text(verbatim: line).font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, Metrics.gutter)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}
