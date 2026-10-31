import AppKit
import Core
import Observation

struct TranscriptSelection: Equatable {
    var text: String
    var seq: Int
    var anchor: CGPoint
}

@MainActor
@Observable
final class TranscriptSelectionReader {
    private(set) var current: TranscriptSelection?

    @ObservationIgnored var accepts: (Int) -> Bool = { _ in false }
    @ObservationIgnored private weak var controller: TranscriptTableController?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var clipObserver: NSObjectProtocol?
    @ObservationIgnored private weak var observedClip: NSClipView?

    func start(controller: TranscriptTableController) {
        self.controller = controller
        observeClip()
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .keyDown]
        ) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let clipObserver { NotificationCenter.default.removeObserver(clipObserver) }
        clipObserver = nil
        observedClip = nil
        current = nil
    }

    func clear() {
        if current != nil { current = nil }
    }

    private func observeClip() {
        guard let clip = controller?.scrollView?.contentView, clip !== observedClip else { return }
        if let clipObserver { NotificationCenter.default.removeObserver(clipObserver) }
        observedClip = clip
        clipObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: clip, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.clear() }
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let scroll = controller?.scrollView, event.window === scroll.window else { return false }
        switch event.type {
        case .leftMouseDown:
            clear()
        case .leftMouseUp:
            let location = event.locationInWindow
            Task { @MainActor [weak self] in self?.read(at: location) }
        case .keyDown where event.keyCode == 53 && current != nil:
            clear()
            return true
        default:
            break
        }
        return false
    }

    private func read(at location: CGPoint) {
        observeClip()
        guard let table = controller?.tableView, let scroll = controller?.scrollView,
              let responder = scroll.window?.firstResponder as? NSView,
              responder.isDescendant(of: table) else { return clear() }
        let row = table.row(for: responder)
        guard row >= 0, let seq = controller?.entryID(atRow: row)?.seq, accepts(seq),
              let text = responder.accessibilitySelectedText(),
              SelectionQuote.quote(text) != nil else { return clear() }
        let host = scroll.superview ?? scroll
        let point = host.convert(location, from: nil)
        let anchor = CGPoint(x: point.x, y: host.isFlipped ? point.y : host.bounds.height - point.y)
        current = TranscriptSelection(text: text, seq: seq, anchor: anchor)
    }
}
