import SwiftUI
import AppKit

struct PaneDivider: View {
    var axis: Axis

    @Binding var length: Double

    var bounds: ClosedRange<Double>

    var reset: Double

    var label: String

    @State private var dragOrigin: Double?

    private static let step: Double = 24

    var body: some View {
        Rectangle()
            .fill(Palette.border)
            .frame(
                width: axis == .horizontal ? Metrics.hairline : nil,
                height: axis == .vertical ? Metrics.hairline : nil
            )
            .frame(
                width: axis == .horizontal ? Metrics.spacingWide : nil,
                height: axis == .vertical ? Metrics.spacingWide : nil
            )
            .contentShape(Rectangle())
            .resizeCursor(axis == .horizontal ? .resizeLeftRight : .resizeUpDown)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        let origin = dragOrigin ?? length
                        if dragOrigin == nil { dragOrigin = origin }
                        let travelled = axis == .horizontal
                            ? drag.translation.width
                            : drag.translation.height
                        length = (origin - Double(travelled)).clamped(to: bounds)
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .onTapGesture(count: 2) { length = reset.clamped(to: bounds) }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? Self.step : -Self.step
                length = (length + step).clamped(to: bounds)
            }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
