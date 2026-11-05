import AppKit
import SwiftUI

#if DEBUG
@MainActor
enum MarkdownTableProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--markdown-table-probe") }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static func run() async {
        var checks = 0
        var failures: [String] = []
        func check(_ passed: Bool, _ message: String) {
            checks += 1
            if !passed { failures.append(message) }
        }
        let samples = [
            """
            | Native option | Fit for Unified Dev |
            | --- | --- |
            | **Window tabs** (`NSWindowTabGroup`) | Provides native window tabbing, but each tab represents an entire window. This would require significant changes to Unified Dev's tabs and split panes. [Apple documentation](https://developer.apple.com/documentation/appkit/nswindowtabgroup) |
            | **In-view tabs** (`NSTabViewController` with a segmented control) | Can sit inside our existing layout and supplies native styling and sizing. Closing, reordering and dragging tabs into splits would still need additional implementation. |
            """,
            """
            | Feature | Before | After | Reference |
            | :--- | :---: | ---: | --- |
            | A long descriptive feature name | Text that previously ran beyond the edge | Cells wrap within the available width | [Documentation for a long identifier](https://developer.apple.com/) |
            | `AnExtremelyLongUnbrokenTypeNameThatMustStillFit` | Some more text | A readable result | A final ordinary cell |
            """,
        ]
        let controller = NSHostingController(rootView: AnyView(EmptyView()))
        controller.sizingOptions = []
        let host = controller.view
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 1600),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentViewController = controller
        for sample in samples {
            for streaming in [false, true] {
                for scale: CGFloat in [1, 1.4] {
                    var wideHeight: CGFloat = 0
                    for width: CGFloat in [680, 420] {
                        controller.rootView = AnyView(
                            MarkdownView(sample, isStreaming: streaming)
                                .environment(\.fontScale, scale)
                                .frame(width: width, alignment: .topLeading)
                                .fixedSize(horizontal: false, vertical: true)
                        )
                        try? await Task.sleep(for: .milliseconds(60))
                        let size = controller.sizeThatFits(in: CGSize(width: width, height: 10_000))
                        host.setFrameSize(size)
                        host.layoutSubtreeIfNeeded()
                        check(abs(size.width - width) < 1, "table exceeded its \(width)-point column")
                        check(size.height > 50 && size.height.isFinite, "table had invalid height")
                        if width == 680 {
                            wideHeight = size.height
                        } else {
                            check(size.height > wideHeight, "narrow cells did not wrap onto more lines")
                        }
                        let answers = MarkdownSelectionProbe.textViews(in: host)
                        check(!answers.isEmpty, "the answer's text view was missing")
                        for answer in answers {
                            let frame = answer.convert(answer.bounds, to: host)
                            check(frame.minX >= -1 && frame.maxX <= width + 1, "the answer extended beyond the table")
                            let font = answer.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
                            check(font?.pointSize == (12 * scale).rounded(), "table did not use the smaller label font")
                        }
                    }
                }
            }
        }
        check(!window.isVisible, "the probe displayed a window")
        let result: [String: Any] = ["checks": checks, "failures": failures, "passed": failures.isEmpty]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            FileHandle.standardOutput.write(data)
        }
        exit(failures.isEmpty ? 0 : 1)
    }
}
#endif
