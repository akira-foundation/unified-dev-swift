import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum SelectionReplyProbe {
    private static let harness = ProbeHarness(subject: "selection-reply")
    static var isRequested: Bool { harness.isRequested }
    static func schedule() { Task { @MainActor in await run() } }

    @MainActor
    private final class Log {
        var ran: [String] = []
        var replied: [String] = []
    }

    private final class FocusedWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var isKeyWindow: Bool { true }
    }

    private static func mouse(_ type: NSEvent.EventType, _ point: NSPoint, in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        )!
    }

    private static func click(_ point: NSPoint, in window: NSWindow) async {
        NSApp.postEvent(mouse(.leftMouseUp, point, in: window), atStart: false)
        NSApp.sendEvent(mouse(.leftMouseDown, point, in: window))
        NSApp.sendEvent(mouse(.leftMouseUp, point, in: window))
        try? await Task.sleep(for: .milliseconds(300))
    }

    private static func key(_ character: String, _ code: UInt16, in window: NSWindow) async {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            NSApp.sendEvent(NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: character,
                charactersIgnoringModifiers: character, isARepeat: false, keyCode: code
            )!)
        }
        try? await Task.sleep(for: .milliseconds(200))
    }

    private static func run() async {
        for _ in 0..<120 where ProbeHarness.appModel == nil { try? await Task.sleep(for: .milliseconds(250)) }
        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        var failures: [String] = []
        func check(_ passed: Bool, _ message: String) {
            if !passed { failures.append(message) }
        }
        let window = FocusedWindow(contentRect: NSRect(x: -6000, y: -6000, width: 640, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.orderFront(nil)
        let log = Log()
        let actions = TranscriptLinkActions(identity: .workspace(nil, pane: "probe", session: nil), runCommand: { log.ran.append($0) })
        let controller = TranscriptTableController()
        let reader = TranscriptSelectionReader()
        reader.accepts = { _ in true }
        let text = "An answer worth quoting, long enough to drag across.\n\n```bash\nls -la\n```\n\nThe last line."
        let entries = [TranscriptTableEntry(
            id: .row(1), contentKey: TranscriptContentKey { $0.combine("answer") }, shape: .answer,
            content: { AnyView(MarkdownView(text).environment(\.markdownRunsCommands, true).proseLeading().padding(8)) }
        ), .bottomSpacing]
        let table = TranscriptTable(
            entries: entries, session: SessionID("reply-probe"), controller: controller,
            scale: ChatTextSize.defaultChoice.scale,
            rowEnvironment: TranscriptRowEnvironment(
                app: app, hoverHost: TranscriptHoverHost(), bubbleWidth: TranscriptBubbleWidth(),
                linkActions: actions, fontScale: ChatTextSize.defaultChoice.scale,
                chatFont: .standard, lineHeight: .defaultChoice, reduceMotion: true
            ),
            onGeometryChange: { _ in }, onSettled: {}, onLiveScrollChange: { _ in }
        )
        let overlay = SelectionActionOverlay(reader: reader, onSideChat: nil, agent: "Claude Code", onReply: { log.replied.append("\($0.text)|\($1)") })
        let host = NSHostingView(rootView: AnyView(table.overlay { overlay }))
        window.contentView = host
        for _ in 0..<16 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(150))
        }
        reader.start(controller: controller)
        guard let view = MarkdownSelectionProbe.textViews(in: host).first, let header = view.markdown?.chromeViews.first,
              let layout = view.layoutManager, let container = view.textContainer else { harness.fail("no answer") }
        func place(_ index: Int) -> NSPoint {
            let rect = layout.boundingRect(forGlyphRange: NSRange(location: layout.glyphIndexForCharacter(at: index), length: 1), in: container)
            return view.convert(NSPoint(x: rect.midX + view.textContainerOrigin.x, y: rect.midY + view.textContainerOrigin.y), to: nil)
        }

        let runPoint = NSPoint(
            x: header.frame.maxX - MarkdownMetrics.blockGap - MarkdownMetrics.iconButton * 1.5 - Metrics.spacing,
            y: header.frame.minY + Metrics.spacing + MarkdownMetrics.iconButton / 2
        )
        await click(view.convert(runPoint, to: nil), in: window)
        check(log.ran == ["ls -la"], "Run in a transcript row ran \(log.ran)")

        let from = place(0)
        let to = place(20)
        window.makeFirstResponder(view)
        NSApp.postEvent(mouse(.leftMouseDragged, to, in: window), atStart: false)
        NSApp.postEvent(mouse(.leftMouseUp, to, in: window), atStart: false)
        view.mouseDown(with: mouse(.leftMouseDown, from, in: window))
        NSApp.sendEvent(mouse(.leftMouseDown, from, in: window))
        try? await Task.sleep(for: .milliseconds(400))
        guard let selected = reader.current else { harness.fail("the drag raised no selection bar") }
        check(reader.barFrame.width < 200 && reader.barFrame.height < 80, "the bar claims \(reader.barFrame), so a press beside it reads as a press on it")

        reader.beginReply(to: TranscriptSelection(text: selected.text, seq: selected.seq, anchor: CGPoint(x: 240, y: 320)))
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(120))
        }
        check(reader.replying != nil, "the reply card did not open")
        await click(host.convert(NSPoint(x: reader.replyFrame.minX + 40, y: reader.replyFrame.maxY - 24), to: nil), in: window)
        check(reader.replying != nil, "a click in the reply field closed the card")
        await key("a", 0, in: window)
        check((window.firstResponder as? NSTextView)?.string == "a", "typing did not reach the reply field: \(String(describing: window.firstResponder))")
        await key("\r", 36, in: window)
        check(log.replied == ["\(selected.text)|a"], "Return replied with \(log.replied)")
        check(reader.replying == nil, "the card stayed open after Return")

        harness.write(.object(["passed": .bool(failures.isEmpty), "failures": .array(failures.map(JSONValue.string))]))
        exit(failures.isEmpty ? 0 : 1)
    }
}
#endif
