import AppKit
import Core
import SwiftUI

/// Resizes the window, hard, and reports whether it survived.
///
/// **It exists to settle a claim that had outlived its measurement.** `RootView` carried a note
/// saying `.inspector()` could not be used in this window because presenting one threw "more
/// Update Constraints in Window passes than there are views in the window" and killed the window
/// during a resize. A snapshot proved the first half wrong: the window draws. The second half
/// needed a resize, and the probe that does resizes, `ResizeProbe`, needs a workspace whose
/// worktree is on disk, which the capture database deliberately does not have.
///
/// So this one asks less. It does not measure frames, it does not need a transcript, and it does
/// not care what is in the panes: it opens the window at the selection it is given, shows the
/// inspector, and walks the frame across a range of widths several times. A layout that cannot
/// survive that takes the process with it, and the harness writes nothing; a run that reaches the
/// end writes a report saying how many passes it made.
///
/// Offscreen, like every other probe here: the window is never brought to the front. See
/// `ProbeHarness.window`.
@MainActor
enum WindowResizeProbe {
    private static let harness = ProbeHarness(subject: "window-resize")
    static var isRequested: Bool { harness.isRequested }
    static func schedule() { Task { @MainActor in await run() } }

    /// How many times the window is walked from wide to narrow and back.
    private static var sweeps: Int { Int(ProbeHarness.points("--window-resize-sweeps", or: 6)) }
    /// How far each step moves the trailing edge. Small enough that a sweep is tens of layout
    /// passes rather than two.
    private static var step: CGFloat { ProbeHarness.points("--window-resize-step", or: 12) }
    private static var narrowest: CGFloat { ProbeHarness.points("--window-resize-narrowest", or: 900) }
    private static var widest: CGFloat { ProbeHarness.points("--window-resize-widest", or: 1_400) }

    private static func run() async {
        let (window, _) = await harness.window()
        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }

        // Whatever `--select` named, plus the pane under test. A workspace whose worktree is gone
        // still opens its column and its inspector, which is all this probe needs.
        app.isInspectorVisible = true
        try? await Task.sleep(for: .seconds(3))

        var passes = 0
        for _ in 0..<sweeps {
            passes += await walk(window, from: widest, to: narrowest)
            passes += await walk(window, from: narrowest, to: widest)
            // And the pane opening and closing under the same layout, which is the other half of
            // what the note said was fatal.
            app.isInspectorVisible = false
            try? await Task.sleep(for: .milliseconds(250))
            app.isInspectorVisible = true
            try? await Task.sleep(for: .milliseconds(250))
        }

        harness.write(.object([
            "survived": .bool(true),
            "passes": .number(Double(passes)),
            "sweeps": .number(Double(sweeps)),
        ]))
        exit(0)
    }

    /// Walks the window's width, a step at a time, letting each frame settle.
    private static func walk(_ window: NSWindow, from: CGFloat, to: CGFloat) async -> Int {
        var width = from
        var passes = 0
        let direction: CGFloat = from > to ? -step : step
        while (direction < 0 && width > to) || (direction > 0 && width < to) {
            width += direction
            var frame = window.frame
            frame.size.width = width
            window.setFrame(frame, display: true)
            window.layoutIfNeeded()
            passes += 1
            try? await Task.sleep(for: .milliseconds(16))
        }
        return passes
    }
}
