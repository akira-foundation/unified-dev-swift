import AppKit
import Core
import Observation

struct TranscriptSelection: Equatable {
    var text: String
    var anchor: CGPoint
}

@MainActor
@Observable
final class TranscriptSelectionReader {
    private(set) var current: TranscriptSelection?

    @ObservationIgnored var accepts: (Int) -> Bool = { _ in false }
    @ObservationIgnored var onContextMenu: (Int, String?, NSEvent, NSView) -> Void = { _, _, _, _ in }
    @ObservationIgnored var onAttach: (String) -> Void = { _ in }
    @ObservationIgnored var barFrame: CGRect = .null
    @ObservationIgnored private var release: Task<Void, Never>?
    @ObservationIgnored private weak var controller: TranscriptTableController?
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var clipObserver: NSObjectProtocol?
    @ObservationIgnored private weak var observedClip: NSClipView?

    func start(controller: TranscriptTableController) {
        self.controller = controller
        observeClip()
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return consumed ? nil : event
        }
    }

    func stop() {
        release?.cancel()
        release = nil
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
            guard !barFrame.contains(hostPoint(event.locationInWindow, in: scroll)) else { return false }
            clear()
            if isInTable(event) { readOnRelease(ignoring: pressesSelectedText(event) ? nil : selectedText()?.text) }
        case .rightMouseDown:
            return isInTable(event) && showMenu(for: event)
        case .keyDown where event.keyCode == 53 && current != nil && responderIsInTable:
            clear()
            return true
        case .keyDown where Self.isAttachShortcut(event):
            guard let text = selectedText() else { return false }
            clear()
            onAttach(text.text)
            return true
        default:
            break
        }
        return false
    }

    private var responderIsInTable: Bool {
        guard let table = controller?.tableView, let responder = table.window?.firstResponder as? NSView else {
            return false
        }
        return responder.isDescendant(of: table)
    }

    private func pressesSelectedText(_ event: NSEvent) -> Bool {
        guard let responder = controller?.tableView?.window?.firstResponder as? NSView,
              let hit = responder.window?.contentView?.hitTest(event.locationInWindow) else { return false }
        return hit.isDescendant(of: responder)
    }

    private func isInTable(_ event: NSEvent) -> Bool {
        guard let table = controller?.tableView,
              let hit = table.window?.contentView?.hitTest(event.locationInWindow) else { return false }
        return hit.isDescendant(of: table)
    }

    private func hostPoint(_ location: CGPoint, in scroll: NSScrollView) -> CGPoint {
        let host = scroll.superview ?? scroll
        let point = host.convert(location, from: nil)
        return CGPoint(x: point.x, y: host.isFlipped ? point.y : host.bounds.height - point.y)
    }

    private func readOnRelease(ignoring previous: String?) {
        release?.cancel()
        release = Task { @MainActor [weak self] in
            while NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(30))
                if Task.isCancelled { return }
            }
            self?.read(ignoring: previous)
        }
    }

    private static func isAttachShortcut(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift]
            && event.charactersIgnoringModifiers?.lowercased() == "l"
    }

    private func selectedText() -> (text: String, seq: Int)? {
        guard let table = controller?.tableView,
              let responder = table.window?.firstResponder as? NSView,
              responder.isDescendant(of: table) else { return nil }
        let row = table.row(for: responder)
        guard row >= 0, let seq = controller?.entryID(atRow: row)?.seq, accepts(seq),
              let text = (responder as? LinkTextView)?.selectedTranscriptText ?? responder.accessibilitySelectedText(),
              SelectionQuote.quote(text) != nil else { return nil }
        return (text, seq)
    }

    private func showMenu(for event: NSEvent) -> Bool {
        guard let table = controller?.tableView, let scroll = controller?.scrollView else { return false }
        let point = table.convert(event.locationInWindow, from: nil)
        guard scroll.contentView.documentVisibleRect.contains(point) else { return false }
        let row = table.row(at: point)
        guard row >= 0, let seq = controller?.entryID(atRow: row)?.seq, accepts(seq) else { return false }
        let hit = scroll.window?.contentView?.hitTest(event.locationInWindow)
        if let link = hit as? LinkTextView, link.hasLink(atWindowPoint: event.locationInWindow) { return false }
        let selection = selectedText().flatMap { $0.seq == seq ? $0.text : nil }
        clear()
        onContextMenu(seq, selection, event, table)
        return true
    }

    private func read(ignoring previous: String?) {
        observeClip()
        guard let scroll = controller?.scrollView, let window = scroll.window,
              let picked = selectedText(), picked.text != previous else { return clear() }
        let anchor = hostPoint(window.mouseLocationOutsideOfEventStream, in: scroll)
        current = TranscriptSelection(text: picked.text, anchor: anchor)
    }
}
