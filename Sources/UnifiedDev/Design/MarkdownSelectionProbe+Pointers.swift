import AppKit
import Core
import ObjectiveC
import SwiftUI

#if DEBUG
extension MarkdownSelectionProbe {
    static func pointers(check: (Bool, String) -> Void) async {
        let run = CodeBlockRun.finished(status: 0, output: "total 0\nprobe output line\n", duration: .seconds(1))
        let actions = TranscriptLinkActions(
            runCommand: { _ in },
            commandRun: { $0 == "ls -la" ? run : nil }
        )
        let window = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 900), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let folded = (0...MarkdownTextBuilder.lineCap).map { "echo \($0)" }.joined(separator: "\n")
        let text = "Before [a link](https://example.com) and text.\n\n```bash\nls -la\n```\n\nMiddle prose.\n\n```bash\n\(folded)\n```\n\nAfter."
        let host = NSHostingView(rootView: AnyView(root(actions: actions, text: text)))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 900)
        window.contentView = host
        window.orderFront(nil)
        await settle(host)
        guard let view = textViews(in: host).first, let storage = view.textStorage,
              let chrome = view.markdown?.chromeViews, chrome.count == 4 else {
            return check(false, "no code block chrome to point at")
        }
        func point(_ needle: String, _ offset: Int = 0) -> NSPoint {
            MarkdownSelectionProbe.point(of: (storage.string as NSString).range(of: needle).location + offset, in: view)
        }
        func expect(_ pointer: NSCursor, at local: NSPoint, _ name: String) {
            NSCursor.crosshair.set()
            check(NSCursor.current == .crosshair, "the probe cannot read the cursor")
            let spot = view.convert(local, to: nil)
            let update = NSEvent.enterExitEvent(
                with: .cursorUpdate, location: spot, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, trackingNumber: 0, userData: nil
            )!
            let routes: [(String, () -> Void)] = [
                ("mouseMoved", { view.mouseMoved(with: mouseEvent(.mouseMoved, at: spot, in: window)) }),
                ("cursorUpdate", { view.cursorUpdate(with: update) }),
                ("routed cursorUpdate", { window.contentView?.hitTest(spot)?.cursorUpdate(with: update) }),
            ]
            for (route, deliver) in routes {
                NSCursor.crosshair.set()
                deliver()
                check(NSCursor.current == pointer, "\(route) over \(name) left \(describe(NSCursor.current)), wanted \(describe(pointer))")
            }
        }

        let header = chrome[0], footer = chrome[1], foldFooter = chrome[3]
        let top = header.frame.minY + Metrics.spacing + MarkdownMetrics.iconButton / 2
        let copyX = header.frame.maxX - MarkdownMetrics.blockGap - MarkdownMetrics.iconButton / 2
        let showOutput = NSPoint(x: footer.frame.maxX - MarkdownMetrics.blockGap - 20, y: footer.frame.midY)

        expect(.arrow, at: NSPoint(x: copyX - MarkdownMetrics.iconButton - Metrics.spacing, y: top), "Run")
        expect(.arrow, at: NSPoint(x: copyX, y: top), "Copy")
        expect(.arrow, at: NSPoint(x: header.frame.minX + MarkdownMetrics.blockGap + 4, y: top), "the language label")
        expect(.arrow, at: showOutput, "Show output")
        expect(.arrow, at: NSPoint(x: footer.frame.minX + 60, y: footer.frame.midY), "the status row")
        expect(.iBeam, at: point("ls -la"), "code")
        expect(.iBeam, at: point("Middle prose"), "prose")
        expect(.pointingHand, at: point("a link", 2), "a link")

        let link = point("a link", 2)
        let linkIndex = (storage.string as NSString).range(of: "a link").location + 2
        let copy = NSPoint(x: copyX, y: top)
        view.mouseMoved(with: mouseEvent(.mouseMoved, at: view.convert(link, to: nil), in: window))
        check(view.layoutManager?.temporaryAttribute(.underlineStyle, atCharacterIndex: linkIndex, effectiveRange: nil) != nil, "the link was not underlined under the pointer")
        view.mouseMoved(with: mouseEvent(.mouseMoved, at: view.convert(copy, to: nil), in: window))
        check(view.layoutManager?.temporaryAttribute(.underlineStyle, atCharacterIndex: linkIndex, effectiveRange: nil) == nil, "the link stayed underlined with the pointer on Copy")

        guard let bar = footer as? MarkdownChromeHost, let toggle = button(in: bar) else {
            return check(false, "no AppKit button in the status row to open the output with")
        }
        toggle.performClick(nil)
        if let output = await openedOutput(in: bar, of: view, host: host) {
            expect(.iBeam, at: output, "a command's output")
        } else {
            check(false, "a command's output never opened under the pointer")
        }
        button(in: bar)?.performClick(nil)
        for _ in 0..<150 where !bar.selectableText.isNull {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(100))
        }
        check(bar.selectableText.isNull, "the closed output kept its rect: \(bar.selectableText)")

        view.scrollToVisible(foldFooter.frame)
        await settle(host)
        expect(.arrow, at: NSPoint(x: foldFooter.frame.minX + MarkdownMetrics.blockGap + 20, y: foldFooter.frame.midY), "the fold")
        for (bar, name) in [(header, "header"), (footer, "footer")] {
            let added = cursorRects(of: bar)
            check(added.contains { $0.rect == bar.bounds && $0.cursor == .arrow }, "the \(name) left its rect to the text view's I-beam: \(added)")
        }
        window.close()
    }

    @MainActor
    private final class CursorRects {
        var added: [(rect: NSRect, cursor: NSCursor)] = []
    }

    private static func cursorRects(of view: NSView) -> [(rect: NSRect, cursor: NSCursor)] {
        let log = CursorRects()
        let method = class_getInstanceMethod(NSView.self, #selector(NSView.addCursorRect(_:cursor:)))!
        let block: @convention(block) (NSView, NSRect, NSCursor) -> Void = { _, rect, cursor in
            MainActor.assumeIsolated { log.added.append((rect, cursor)) }
        }
        let original = method_setImplementation(method, imp_implementationWithBlock(block))
        defer { method_setImplementation(method, original) }
        view.resetCursorRects()
        return log.added
    }

    private static func openedOutput(in bar: MarkdownChromeHost, of view: NSView, host: NSView) async -> NSPoint? {
        for _ in 0..<150 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(100))
            let middle = NSPoint(x: bar.selectableText.midX, y: bar.selectableText.midY)
            if !bar.selectableText.isNull, bar.bounds.contains(middle) { return bar.convert(middle, to: view) }
        }
        return nil
    }

    private static func button(in root: NSView) -> NSButton? {
        (root as? NSButton) ?? root.subviews.lazy.compactMap(button).first
    }

    private static func settle(_ host: NSView) async {
        for _ in 0..<6 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private static func describe(_ cursor: NSCursor) -> String {
        switch cursor {
        case .arrow: "the arrow"
        case .iBeam: "the I-beam"
        case .pointingHand: "the hand"
        case .crosshair: "nothing"
        default: "another cursor"
        }
    }
}
#endif
