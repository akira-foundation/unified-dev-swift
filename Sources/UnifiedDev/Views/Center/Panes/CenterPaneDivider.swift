import SwiftUI
import Core

struct CenterPaneDivider: View {
    var axis: SplitAxis
    var ratio: Double
    var span: Double
    var length: Double
    var line: CGRect
    var first: String?
    var second: String?
    var onResize: (Double) -> Void
    var onResizeEnded: () -> Void
    var onMoveChanged: (String, CGPoint) -> Void
    var onMoveEnded: (String, CGPoint) -> Void

    @State private var dragOrigin: Double?
    @State private var carrying: String?
    @State private var pointer: CGPoint?

    private static let reach: CGFloat = 12
    private static let resizeReach: CGFloat = 5
    private static let step: Double = 0.05

    var body: some View {
        Rectangle()
            .fill(Palette.border)
            .frame(
                width: axis == .horizontal ? Metrics.hairline : nil,
                height: axis == .vertical ? Metrics.hairline : nil
            )
            .frame(
                width: axis == .horizontal ? Self.reach * 2 : length,
                height: axis == .vertical ? Self.reach * 2 : length
            )
            .contentShape(band)
            .pointerStyle(pointerStyle)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point): pointer = point
                case .ended: pointer = nil
                }
            }
            .gesture(drag)
            .onTapGesture(count: 2) {
                onResize(0.5)
                onResizeEnded()
            }
            .onDisappear { finishResize() }
            .accessibilityElement()
            .accessibilityLabel(axis == .horizontal ? "Pane divider" : "Pane divider, stacked")
            .accessibilityValue(Text(ratio, format: .percent.precision(.fractionLength(0))))
            .accessibilityAdjustableAction { direction in
                onResize(ratio + (direction == .increment ? Self.step : -Self.step))
                onResizeEnded()
            }
    }

    private func across(of point: CGPoint?) -> CGFloat? {
        guard let point else { return nil }
        return (axis == .horizontal ? point.x : point.y) - Self.reach
    }

    private var isOfferingMove: Bool {
        pointer != nil && carrying == nil && (first != nil || second != nil)
    }

    private var band: some Shape {
        let half = isOfferingMove ? Self.reach : Self.resizeReach
        var path = Path()
        path.addRect(axis == .horizontal
            ? CGRect(x: Self.reach - half, y: 0, width: half * 2, height: length)
            : CGRect(x: 0, y: Self.reach - half, width: length, height: half * 2))
        return path
    }

    private func pane(at point: CGPoint) -> String? {
        guard let across = across(of: point), abs(across) > Self.resizeReach else { return nil }
        return across < 0 ? first : second
    }

    private var pointerStyle: PointerStyle? {
        guard let pointer else { return nil }
        if pane(at: pointer) != nil { return .grabIdle }
        return axis == .horizontal ? .columnResize : .rowResize
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(CenterPanesView.space))
            .onChanged { value in
                if dragOrigin == nil, carrying == nil {
                    carrying = pane(at: local(value.startLocation))
                    if carrying == nil {
                        dragOrigin = ratio
                    }
                }
                if let carrying {
                    return onMoveChanged(carrying, value.location)
                }
                guard span > 0, let origin = dragOrigin else { return }
                let travelled = axis == .horizontal
                    ? value.translation.width
                    : value.translation.height
                onResize(origin + Double(travelled) / span)
            }
            .onEnded { value in
                if let carrying { onMoveEnded(carrying, value.location) }
                carrying = nil
                finishResize()
            }
    }

    private func finishResize() {
        guard dragOrigin != nil else { return }
        onResizeEnded()
        dragOrigin = nil
    }

    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - line.midX + Self.reach,
            y: point.y - line.midY + (axis == .horizontal ? length / 2 : Self.reach)
        )
    }
}
