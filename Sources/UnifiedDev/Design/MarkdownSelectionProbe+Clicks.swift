import AppKit
import SwiftUI

#if DEBUG
extension MarkdownSelectionProbe {
    @MainActor
    private final class Log {
        var ran: [String] = []
        var followed: [URL] = []
    }

    static func clicks(check: (Bool, String) -> Void) async {
        let log = Log()
        let actions = TranscriptLinkActions(
            open: { url, _ in log.followed.append(url) },
            runCommand: { log.ran.append($0) },
            commandRun: { _ in nil }
        )
        let window = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let text = "Before [a link](https://example.com) and text.\n\n```bash\nls -la\n```\n\nAfter."
        let host = NSHostingView(rootView: AnyView(root(actions: actions, text: text)))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        window.contentView = host
        window.orderFront(nil)
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard let view = textViews(in: host).first, let storage = view.textStorage,
              let header = view.markdown?.chromeViews.first else {
            return check(false, "no code block header")
        }
        let top = header.frame.minY + Metrics.spacing + MarkdownMetrics.iconButton / 2
        let copyX = header.frame.maxX - MarkdownMetrics.blockGap - MarkdownMetrics.iconButton / 2
        let runX = copyX - MarkdownMetrics.iconButton - Metrics.spacing
        func hit(_ point: NSPoint) -> NSView? { window.contentView?.hitTest(view.convert(point, to: nil)) }

        check(hit(NSPoint(x: runX, y: top))?.isDescendant(of: header) == true, "Run gives its click to \(String(describing: hit(NSPoint(x: runX, y: top))))")
        check(hit(NSPoint(x: copyX, y: top))?.isDescendant(of: header) == true, "Copy gives its click to \(String(describing: hit(NSPoint(x: copyX, y: top))))")
        check(hit(NSPoint(x: header.frame.minX + MarkdownMetrics.blockGap + 4, y: top)) === view, "the language label took a selection's press")
        let whole = storage.string as NSString
        check(hit(point(of: whole.range(of: "ls -la").location, in: view)) === view, "the code took a selection's press")

        press(at: view.convert(NSPoint(x: runX, y: top), to: nil), in: window)
        try? await Task.sleep(for: .milliseconds(150))
        check(log.ran == ["ls -la"], "a click on Run ran \(log.ran)")

        if ProcessInfo.processInfo.environment["UD_PROBE_COPIES"] != nil {
            press(at: view.convert(NSPoint(x: copyX, y: top), to: nil), in: window)
            try? await Task.sleep(for: .milliseconds(150))
            check(NSPasteboard.general.string(forType: .string)?.contains("ls -la") == true, "Copy wrote \(String(describing: NSPasteboard.general.string(forType: .string)))")
        }

        let link = view.convert(point(of: whole.range(of: "a link").location + 2, in: view), to: nil)
        window.makeFirstResponder(view)
        NSApp.postEvent(mouseEvent(.leftMouseUp, at: link, in: window), atStart: false)
        view.mouseDown(with: mouseEvent(.leftMouseDown, at: link, in: window))
        check(log.followed.map(\.absoluteString) == ["https://example.com"], "a click on a link followed \(log.followed)")
        let menu = view.menu(for: mouseEvent(.rightMouseDown, at: link, in: window))
        check(menu?.items.contains { $0.title == "Copy Link" } == true, "the secondary click on a link lost its menu")
        window.close()
    }

    private static func press(at point: NSPoint, in window: NSWindow) {
        NSApp.postEvent(mouseEvent(.leftMouseUp, at: point, in: window), atStart: false)
        window.sendEvent(mouseEvent(.leftMouseDown, at: point, in: window))
        window.sendEvent(mouseEvent(.leftMouseUp, at: point, in: window))
    }

    static func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        )!
    }
}
#endif
