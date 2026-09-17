import AppKit
import Core
import SwiftUI

@MainActor
enum CommentFocusProbe {
    private static let harness = ProbeHarness(subject: "comment-focus")
    static var isRequested: Bool { harness.isRequested }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    private static func run() async {
        _ = await harness.window()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 180),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        var failures: [String] = []
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }

        let host = NSHostingView(rootView: ComposerTextEditor(
            text: .constant(""), caret: .constant(0), isFocused: .constant(true),
            onHeightChange: { _ in }, onKey: { _ in false }, onAttach: { _, _ in false }
        ))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 60)
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        let unattached = textView(in: host)
        check(unattached != nil && unattached?.window == nil, "editor was not built before attachment")
        window.contentView = host
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        check(window.firstResponder === unattached, "pre-attachment request did not focus the editor")

        let comment = NSHostingView(rootView: ReviewCommentField(
            text: .constant(""), placeholder: "Leave a comment", onSubmit: {}, onCancel: {}
        ).padding(12))
        window.contentView = comment
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(200))
        let field = textView(in: comment)
        check(field != nil && window.firstResponder === field, "new empty comment did not receive focus")

        let other = NSTextView(frame: NSRect(x: 0, y: 80, width: 100, height: 30))
        comment.addSubview(other)
        window.makeFirstResponder(other)
        comment.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        check(window.firstResponder === other, "comment took focus back after it was moved elsewhere")
        check(!window.isKeyWindow && !window.isVisible, "probe unexpectedly showed or activated its window")
        harness.write(.object([
            "checks": .integer(checks), "passed": .bool(failures.isEmpty),
            "failures": .strings(failures),
        ]))
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func textView(in view: NSView) -> ComposerTextView? {
        if let text = view as? ComposerTextView { return text }
        for child in view.subviews {
            if let text = textView(in: child) { return text }
        }
        return nil
    }
}
