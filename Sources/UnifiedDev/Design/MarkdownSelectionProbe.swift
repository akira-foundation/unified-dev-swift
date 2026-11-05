import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum MarkdownSelectionProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--markdown-selection-probe") }

    static let sample = """
    # A long answer

    The first paragraph has a [link](https://example.com), `inline code`, **strong words** and enough prose to wrap onto a second line inside the column.

    The second paragraph comes straight after it, and a selection has to run through both.

    ## A list

    - A bullet item
    - Another bullet with `code`
      - A nested bullet under it

    1. First numbered
    2. Second numbered

    - [x] A finished task
    - [ ] An open task

    > A quoted paragraph that also wraps because it keeps going for long enough to reach the far edge of the text column.
    >
    > A second quoted paragraph.

    - An item holding code

      ```swift
      let value = 1
      ```

    ```bash
    echo "a command with a very long line that has to wrap inside the block rather than scroll sideways, because the block is part of one text view"
    ls -la
    ```

    | Name | Value | Note |
    | --- | :---: | ---: |
    | Alpha | 1 | The first row |
    | Beta | 2 | The second row of the table, which wraps |

    ---

    The last paragraph, after the rule.
    """

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.finishLaunching()
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static func run() async {
        var failures: [String] = []
        func check(_ passed: Bool, _ message: String) {
            if !passed { failures.append(message) }
        }
        let window = NSWindow(
            contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 1400),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        let actions = TranscriptLinkActions(
            runCommand: { _ in },
            commandRun: { _ in nil }
        )
        let host = NSHostingView(rootView: AnyView(root(actions: actions)))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 1400)
        window.contentView = host
        try? await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        try? await Task.sleep(for: .milliseconds(200))
        host.layoutSubtreeIfNeeded()

        guard let view = textViews(in: host).first, let storage = view.textStorage else {
            finish(["no text view"], window: window)
        }
        check(textViews(in: host).count == 1, "the answer drew \(textViews(in: host).count) text views, not one")

        let whole = storage.string as NSString
        let from = view.convert(point(of: whole.range(of: "The first paragraph").location, in: view), to: nil)
        let to = view.convert(point(of: whole.range(of: "last paragraph").location + 8, in: view), to: nil)
        drag(in: window, target: view, from: from, to: to)
        let copied = view.selectedTranscriptText
        for needle in ["first paragraph", "The second paragraph", "\u{2022} A bullet item", "  \u{2022} A nested bullet", "1. First numbered", "\u{2713} A finished task", "\u{25A1} An open task", "A quoted paragraph", "ls -la", "Name\tValue\tNote", "Alpha\t1\tThe first row", "The last"] {
            check(copied.contains(needle), "the drag lost: \(needle)")
        }
        check(!copied.contains("\t\u{2022}"), "a marker's tab reached the copy")
        check(!copied.contains("\u{00A0}"), "the rule reached the copy")
        check(copied.contains("that has to wrap inside the block rather than scroll sideways, because the block is part of one text view\"\nls -la"), "the wrapped code line was split")
        check(SelectionQuote.quote(copied) != nil, "the selection did not make a quote")
        check(view.accessibilitySelectedText()?.isEmpty == false, "accessibility could not read the selection")
        check((view.accessibilityChildren() ?? []).count >= 2, "accessibility cannot reach a code block's buttons")

        await render(view: view, host: host, window: window, name: "selected", check: check)
        view.setSelectedRange(NSRange(location: 0, length: 0))
        await render(view: view, host: host, window: window, name: "plain", check: check)

        await streaming(check: check)
        await runStatus(check: check)
        cost()
        finish(failures, window: window)
    }

    private static func root(actions: TranscriptLinkActions, text: String = sample, isStreaming: Bool = false) -> some View {
        ScrollView {
            MarkdownView(text, isStreaming: isStreaming)
                .environment(\.markdownLinkActions, actions)
                .environment(\.markdownRunsCommands, true)
                .font(Typo.body)
                .proseLeading()
                .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TranscriptLayout.inset)
        }
        .background(Palette.windowBackground)
    }

    private static func point(of index: Int, in view: LinkTextView) -> NSPoint {
        let layout = view.layoutManager!
        let glyph = layout.glyphIndexForCharacter(at: index)
        var rect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer!)
        rect.origin.x += view.textContainerOrigin.x
        rect.origin.y += view.textContainerOrigin.y
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    private static func drag(in window: NSWindow, target: NSView, from: NSPoint, to: NSPoint) {
        func event(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
            )!
        }
        for step in 1...8 {
            let share = CGFloat(step) / 8
            let moved = NSPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share)
            NSApp.postEvent(event(.leftMouseDragged, moved), atStart: false)
        }
        NSApp.postEvent(event(.leftMouseUp, to), atStart: false)
        window.makeFirstResponder(target)
        target.mouseDown(with: event(.leftMouseDown, from))
    }

    private static func render(
        view: LinkTextView, host: NSView, window: NSWindow, name: String, check: (Bool, String) -> Void
    ) async {
        for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded()
            let bounds = host.bounds
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: bounds) else { continue }
            host.cacheDisplay(in: bounds, to: bitmap)
            let path = outputDirectory + "/markdown-\(name)-\(mode).png"
            try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(filePath: path))
            check(FileManager.default.fileExists(atPath: path), "no picture at \(path)")
        }
    }

    private static var outputDirectory: String {
        ProbeHarness.value(for: "--markdown-selection-probe-out") ?? NSTemporaryDirectory()
    }

    private static func streaming(check: (Bool, String) -> Void) async {
        var text = "Stable first paragraph that stays.\n\nA growing tail"
        let window = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AnyView(root(actions: TranscriptLinkActions(), text: text, isStreaming: true)))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        guard let view = textViews(in: host).first else { return check(false, "no streaming text view") }
        view.setSelectedRange(NSRange(location: 0, length: 6))
        for _ in 0..<4 {
            text += " more words"
            host.rootView = AnyView(root(actions: TranscriptLinkActions(), text: text, isStreaming: true))
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(40))
        }
        host.layoutSubtreeIfNeeded()
        check(view.textStorage?.string.hasSuffix("more words") == true, "the streamed tail was not applied: \(view.textStorage?.string ?? "")")
        check(view.selectedRange() == NSRange(location: 0, length: 6), "a tick moved the selection to \(view.selectedRange())")
        window.close()
    }

    private static func runStatus(check: (Bool, String) -> Void) async {
        let text = "```bash\nls\n```"
        let window = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        func view(_ run: CodeBlockRun?) -> AnyView {
            AnyView(MarkdownView(text)
                .environment(\.markdownLinkActions, TranscriptLinkActions(
                    identity: .workspace(nil, pane: run == nil ? "idle" : "ran", session: nil),
                    runCommand: { _ in },
                    commandRun: { _ in run }
                ))
                .environment(\.markdownRunsCommands, true)
                .frame(width: 600, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true))
        }
        let host = NSHostingView(rootView: view(nil))
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 600)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        host.layoutSubtreeIfNeeded()
        let idle = host.fittingSize.height
        host.rootView = view(.running)
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(80))
        }
        let ran = host.fittingSize.height
        check(ran > idle + 10, "a command's status did not make room: \(idle) to \(ran)")
        window.close()
    }

    private static func cost() {
        let long = (0..<47).map { "Block \($0) " + String(repeating: "the agent explains what changed and why. ", count: 4) }.joined(separator: "\n\n")
        for (name, text) in [("sample", sample), ("47 blocks", long)] {
            var measured: [Double] = []
            let sizer = NSHostingController(rootView: AnyView(EmptyView()))
            for salt in 0..<7 {
                sizer.rootView = AnyView(MarkdownView("\(salt) \(text)").environment(\.lineSpacing, 4))
                let start = DispatchTime.now().uptimeNanoseconds
                _ = sizer.sizeThatFits(in: CGSize(width: 700, height: CGFloat.greatestFiniteMagnitude))
                measured.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
            }
            FileHandle.standardError.write(Data("measure \(name): \(measured.sorted()[3]) ms\n".utf8))
        }
    }

    private static func textViews(in view: NSView) -> [LinkTextView] {
        (view as? LinkTextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }

    private static func finish(_ failures: [String], window: NSWindow) -> Never {
        let result: [String: Any] = ["failures": failures, "passed": failures.isEmpty, "visible": window.isVisible]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            FileHandle.standardOutput.write(data)
        }
        exit(failures.isEmpty ? 0 : 1)
    }
}
#endif
