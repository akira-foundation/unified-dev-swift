import AppKit
import Core
import SwiftUI

@MainActor
enum DividerDragProbe {
    private static let harness = ProbeHarness(subject: "divider-drag")
    static var isRequested: Bool { harness.isRequested }
    static func schedule() { Task { @MainActor in await run() } }

    private static func run() async {
        let (window, _) = await harness.window()
        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        app.isInspectorVisible = true
        try? await Task.sleep(for: .seconds(3))

        guard let root = window.contentView, let split = innermostSplit(under: root) else {
            harness.fail("no split view under the window")
        }

        var splits: [JSONValue] = []
        walk(root) { view in
            guard let split = view as? NSSplitView else { return }
            splits.append(.object([
                "class": .string("\(type(of: split))"),
                "frame": .string("\(split.frame)"),
                "panes": .array(split.arrangedSubviews.map { .string("\($0.frame)") }),
                "vertical": .bool(split.isVertical),
            ]))
        }

        var report: [JSONValue] = []
        let divider = max(split.arrangedSubviews.count - 2, 0)
        for position in [0.55, 0.65, 0.75] {
            let x = split.bounds.width * position
            split.setPosition(x, ofDividerAt: divider)
            window.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(400))
            let frames = toolbarItemFrames(in: window)
            report.append(.object([
                "divider": .number(Double(split.arrangedSubviews[divider].frame.maxX.rounded())),
                "panes": .number(Double(split.arrangedSubviews.count)),
                "itemsAfterDivider": .number(Double(frames.filter { $0 > split.arrangedSubviews[divider].frame.maxX }.count)),
                "itemXs": .array(frames.map { .number(Double($0.rounded())) }),
            ]))
        }

        harness.write(.object(["splits": .array(splits), "drags": .array(report)]))
        exit(0)
    }

    private static func toolbarItemFrames(in window: NSWindow) -> [CGFloat] {
        guard let themeFrame = window.contentView?.superview else { return [] }
        var xs: [CGFloat] = []
        walk(themeFrame) { view in
            guard "\(type(of: view))".contains("NSToolbarItemViewer") else { return }
            xs.append(view.convert(view.bounds, to: themeFrame).minX)
        }
        return xs.sorted()
    }

    private static func innermostSplit(under view: NSView) -> NSSplitView? {
        var found: [NSSplitView] = []
        walk(view) { candidate in
            if let split = candidate as? NSSplitView, split.arrangedSubviews.count >= 2 {
                found.append(split)
            }
        }
        return found.max { $0.arrangedSubviews.count < $1.arrangedSubviews.count } ?? found.last
    }

    private static func walk(_ view: NSView, _ visit: (NSView) -> Void) {
        visit(view)
        for subview in view.subviews { walk(subview, visit) }
    }
}
