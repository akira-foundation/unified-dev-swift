import AppKit
import SwiftUI

extension MarkdownSelectionProbe {
    static func streamingCodeAndLists(check: (Bool, String) -> Void) async {
        let window = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        func answer(_ text: String) -> AnyView { AnyView(root(actions: TranscriptLinkActions(), text: text, isStreaming: true)) }
        let host = NSHostingView(rootView: answer("Intro\n\n```bash\nls\n```\n\nMiddle\n\n- A\n- B"))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 800)
        window.contentView = host
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(80))
        }
        guard let view = textViews(in: host).first, let storage = view.textStorage else {
            return check(false, "no streaming text view")
        }
        check(view.writablePasteboardTypes == [.string], "the answer offers more than its plain copy: \(view.writablePasteboardTypes)")
        let inTail = (storage.string as NSString).range(of: "A")
        view.setSelectedRange(inTail)
        host.rootView = answer("Intro\n\n```bash\nls\n```\n\nMiddle\n\n- A\n- B more")
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(60))
        host.layoutSubtreeIfNeeded()
        check(view.selectedRange() == inTail, "a selection in the live tail moved: \(view.selectedRange())")

        host.rootView = answer("Intro\n\n```bash\nls\n```\n\nMiddle\n\n- A")
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(60))
        host.layoutSubtreeIfNeeded()
        check(storage.string.contains("A") && !storage.string.contains("B"), "a shrinking list was cut: \(storage.string)")
        check(storage.string.contains("Middle"), "the text before a shrinking list was cut: \(storage.string)")

        host.rootView = answer("Intro\n\n```bash\nls\n```\n\nMiddle\n\n* A\n* * *\n\nNext")
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(60))
        host.layoutSubtreeIfNeeded()
        check(storage.string.contains("A"), "a list item became a rule and took its sibling: \(storage.string)")
        check(storage.string.hasSuffix("Next"), "the tail after a rule was lost: \(storage.string)")
        view.layout()
        let header = view.subviews.first
        check((header?.frame.height ?? 0) > 10, "a kept code block lost its header: \(String(describing: header?.frame))")
        window.close()
    }

    static func emptyCells(check: (Bool, String) -> Void) async {
        let window = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 720, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AnyView(root(actions: TranscriptLinkActions(), text: "| A | B | C |\n| --- | --- | --- |\n| a |  | c |\n\n- first  \n  second")))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 400)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        guard let view = textViews(in: host).first, let storage = view.textStorage else {
            return check(false, "no text view for empty cells")
        }
        view.setSelectedRange(NSRange(location: 0, length: storage.length))
        let copied = view.selectedTranscriptText
        check(copied.contains("a\t\tc"), "an empty cell shifted the columns: \(copied.debugDescription)")
        check(copied.contains("first\n  second"), "a hard break lost its place in the item: \(copied.debugDescription)")
        window.close()
    }
}
