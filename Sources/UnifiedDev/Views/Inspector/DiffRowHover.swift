import SwiftUI
import AppKit
import Core

struct DiffRowHover: NSViewRepresentable {
    var rowHeight: CGFloat
    var rowCount: Int
    var rowHeights: [CGFloat]?
    var onChange: (Int?) -> Void

    func makeNSView(context: Context) -> RowHoverView {
        let view = RowHoverView()
        view.rowHeight = rowHeight
        view.rowCount = rowCount
        view.rowHeights = rowHeights
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: RowHoverView, context: Context) {
        view.rowHeight = rowHeight
        view.rowCount = rowCount
        view.rowHeights = rowHeights
        view.onChange = onChange
    }

    final class RowHoverView: NSView {
        var rowHeight: CGFloat = 1
        var rowCount = 0
        var rowHeights: [CGFloat]?
        var onChange: ((Int?) -> Void)?

        private var reported: Int??

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas where area.owner === self {
                removeTrackingArea(area)
            }
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
                owner: self
            ))
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            updateTrackingAreas()
        }

        override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            report(at: convert(event.locationInWindow, from: nil))
        }

        override func mouseMoved(with event: NSEvent) {
            super.mouseMoved(with: event)
            report(at: convert(event.locationInWindow, from: nil))
        }

        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            report(nil)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { report(nil) }
        }

        private func report(at point: NSPoint) {
            guard rowHeight > 0, bounds.contains(point) else { return report(nil) }
            if let rowHeights { return report(DiffDragRange.row(at: point.y, heights: rowHeights)) }
            let index = Int(point.y / rowHeight)
            report((0..<rowCount).contains(index) ? index : nil)
        }

        private func report(_ row: Int?) {
            guard reported != row else { return }
            reported = row
            onChange?(row)
        }
    }
}
