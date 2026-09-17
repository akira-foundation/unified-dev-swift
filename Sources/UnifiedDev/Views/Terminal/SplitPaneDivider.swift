import SwiftUI
import AppKit
import Core

struct SplitPaneDivider: View {
    var axis: SplitAxis
    var ratio: Double
    var span: Double
    var length: Double
    var color: Color
    var onChange: (Double) -> Void
    var onChangeEnded: () -> Void

    @State private var dragOrigin: Double?

    private static let grab: CGFloat = 10
    private static let step: Double = 0.05

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(
                width: axis == .horizontal ? Metrics.hairline : nil,
                height: axis == .vertical ? Metrics.hairline : nil
            )
            .frame(
                width: axis == .horizontal ? Self.grab : length,
                height: axis == .vertical ? Self.grab : length
            )
            .contentShape(Rectangle())
            .resizeCursor(axis == .horizontal ? .resizeLeftRight : .resizeUpDown)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        guard span > 0 else { return }
                        let origin = dragOrigin ?? ratio
                        if dragOrigin == nil { dragOrigin = origin }
                        let travelled = axis == .horizontal
                            ? drag.translation.width
                            : drag.translation.height
                        onChange(origin + Double(travelled) / span)
                    }
                    .onEnded { _ in finishResize() }
            )
            .onTapGesture(count: 2) {
                onChange(0.5)
                onChangeEnded()
            }
            .onDisappear { finishResize() }
            .accessibilityElement()
            .accessibilityLabel(axis == .horizontal ? "Pane divider" : "Pane divider, stacked")
            .accessibilityValue(Text(ratio, format: .percent.precision(.fractionLength(0))))
            .accessibilityAdjustableAction { direction in
                onChange(ratio + (direction == .increment ? Self.step : -Self.step))
                onChangeEnded()
            }
    }

    private func finishResize() {
        guard dragOrigin != nil else { return }
        onChangeEnded()
        dragOrigin = nil
    }
}
