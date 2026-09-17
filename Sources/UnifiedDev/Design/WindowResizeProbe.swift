import AppKit
import Core
import SwiftUI

@MainActor
enum WindowResizeProbe {
    private static let harness = ProbeHarness(subject: "window-resize")
    static var isRequested: Bool { harness.isRequested }
    static func schedule() { Task { @MainActor in await run() } }

    private static var sweeps: Int { Int(ProbeHarness.points("--window-resize-sweeps", or: 6)) }
    private static var step: CGFloat { ProbeHarness.points("--window-resize-step", or: 12) }
    private static var narrowest: CGFloat { ProbeHarness.points("--window-resize-narrowest", or: 900) }
    private static var widest: CGFloat { ProbeHarness.points("--window-resize-widest", or: 1_400) }

    private static func run() async {
        let (window, _) = await harness.window()
        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }

        app.isInspectorVisible = true
        try? await Task.sleep(for: .seconds(3))

        var passes = 0
        for _ in 0..<sweeps {
            passes += await walk(window, from: widest, to: narrowest)
            passes += await walk(window, from: narrowest, to: widest)
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
