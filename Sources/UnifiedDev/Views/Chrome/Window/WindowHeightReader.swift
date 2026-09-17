import SwiftUI
import AppKit

struct WindowHeightReader: NSViewRepresentable {
    var onChange: @MainActor (CGFloat) -> Void

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
    }

    @MainActor
    final class ProbeView: NSView {
        var onChange: (@MainActor (CGFloat) -> Void)?

        nonisolated(unsafe) private var observer: NSObjectProtocol?
        private var reported: CGFloat?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            report()
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
        }

        private func report() {
            guard let height = window?.contentView?.bounds.height, height != reported else { return }
            reported = height
            let onChange = onChange
            Task { @MainActor in onChange?(height) }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }
}
