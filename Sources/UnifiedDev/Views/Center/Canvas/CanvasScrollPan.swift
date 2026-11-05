import AppKit
import SwiftUI

struct CanvasScrollPan: NSViewRepresentable {
    let isEnabled: Bool
    let scroll: (_ deltaX: Double, _ deltaY: Double, _ isPrecise: Bool) -> Void

    func makeNSView(context: Context) -> CanvasScrollPanView {
        let view = CanvasScrollPanView()
        update(view)
        return view
    }

    func updateNSView(_ view: CanvasScrollPanView, context: Context) {
        update(view)
    }

    static func dismantleNSView(_ view: CanvasScrollPanView, coordinator: ()) {
        view.stopMonitoring()
    }

    private func update(_ view: CanvasScrollPanView) {
        view.isEnabled = isEnabled
        view.scroll = scroll
    }
}

final class CanvasScrollPanView: NSView {
    var isEnabled = true
    var scroll: (Double, Double, Bool) -> Void = { _, _, _ in }
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let taken = MainActor.assumeIsolated { self?.take(event) ?? false }
            return taken ? nil : event
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func takesScroll(atWindowPoint point: NSPoint) -> Bool {
        guard isEnabled, bounds.contains(convert(point, from: nil)),
              let hit = window?.contentView?.hitTest(point) else { return false }
        return !(hit is NSScrollView) && hit.enclosingScrollView == nil
    }

    private func take(_ event: NSEvent) -> Bool {
        guard event.window === window, takesScroll(atWindowPoint: event.locationInWindow) else { return false }
        scroll(event.scrollingDeltaX, event.scrollingDeltaY, event.hasPreciseScrollingDeltas)
        return true
    }
}
