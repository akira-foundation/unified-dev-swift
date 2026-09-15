import AppKit
import SwiftUI

extension View {
    /// Draws the rule under the toolbar only while a column boundary has left the bar's own
    /// separator, which is what Mail and Notes do.
    ///
    /// One modifier for every window in this app that has a sidebar, rather than a rule written
    /// again per window: the main window, Settings and a project's settings all get the same
    /// behaviour from this line.
    /// The rule under the toolbar, drawn while the window has a column boundary for it to close
    /// off and gone when it has none.
    ///
    /// One modifier for every window in this app with a sidebar, rather than the same line written
    /// again per window.
    func tracksColumnRule(isActive: Bool = true) -> some View { modifier(ColumnRule(isActive: isActive)) }

    /// Keeps the window's last column collapsed while there is nothing for it to show, and open
    /// whenever there is.
    ///
    /// `NavigationSplitViewVisibility` cannot do this, measured: in a three column split
    /// `.doubleColumn` hides the SIDEBAR, so setting it left the empty column and its divider
    /// where they were. The column is an `NSSplitViewItem` underneath and an item collapses
    /// itself.
    ///
    /// Both directions are a straight assignment. The first version collapsed through
    /// `animator()`, and the column never came back: the panel read as having disappeared for
    /// good, which is the one thing the owner asked never to happen.
    func collapsesLastColumn(when isEmpty: Bool) -> some View {
        background(SplitWatcher { split in
            guard let controller = split.delegate as? NSSplitViewController,
                  controller.splitViewItems.count >= 3, let last = controller.splitViewItems.last,
                  last.isCollapsed != isEmpty else { return }
            last.isCollapsed = isEmpty
        })
    }

}

/// The rule under the toolbar, and the one question it depends on.
///
/// **Why the toolbar's background and not `titlebarSeparatorStyle`.** Both were measured on this
/// window. `NSWindow.titlebarSeparatorStyle` draws nothing at all while the toolbar has no ground
/// of its own: with `.line` forced and the background hidden, the row at y 51 came back uniform
/// with the content above and below it. The background is what carries the rule, so the background
/// is what comes and goes.
private struct ColumnRule: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.toolbarBackgroundVisibility(isActive ? .visible : .hidden, for: .windowToolbar)
    }
}

/// Whether every separator the bar drew is still sitting on its column boundary.
enum ColumnAlignment {
    /// Measured on this window: the dividers are at 208 and 1,119 and the bar draws exactly one
    /// separator, at 1,109.5, because a sidebar's own separator is never materialised. So only the
    /// boundaries that HAVE a separator are judged, and a bar with none has nothing to line up.
    ///
    /// The tolerance is the toolbar's own packing rather than a pixel: while the separator follows
    /// the divider it sits a few points off it, and when the divider goes where the bar cannot
    /// follow, the two part company by far more than this.
    @MainActor
    static func isAligned(_ split: NSSplitView) -> Bool {
        guard let window = split.window else { return true }
        let separators = separatorPositions(in: window)
        guard !separators.isEmpty else { return true }
        let dividers = dividerPositions(of: split).suffix(separators.count)
        guard dividers.count == separators.count else { return false }
        return zip(dividers, separators).allSatisfy { abs($0 - $1) <= 12 }
    }

    @MainActor
    static func debug(_ split: NSSplitView) -> String {
        let separators = split.window.map { separatorPositions(in: $0) } ?? []
        return "dividers=\(dividerPositions(of: split)) separators=\(separators)"
    }

    @MainActor
    private static func dividerPositions(of split: NSSplitView) -> [CGFloat] {
        let panes = split.arrangedSubviews.filter { !split.isSubviewCollapsed($0) }
        guard panes.count > 1 else { return [] }
        return panes.dropLast().map { $0.convert(CGPoint(x: $0.bounds.maxX, y: 0), to: nil).x }
    }

    @MainActor
    private static func separatorPositions(in window: NSWindow) -> [CGFloat] {
        guard let frame = window.contentView?.superview else { return [] }
        var found: [CGFloat] = []
        func walk(_ view: NSView) {
            if "\(type(of: view))".contains("SeparatorToolbarItemView") {
                found.append(view.convert(view.bounds, to: nil).midX)
            }
            for sub in view.subviews { walk(sub) }
        }
        for sub in frame.subviews where "\(type(of: sub))".contains("Titlebar") { walk(sub) }
        return found.sorted()
    }
}

/// Calls back whenever the window's split view moves a boundary.
///
/// On the split's own notification rather than on every layout pass, which was the first version
/// and was wrong twice over: reading a position from inside a layout answered a frame behind the
/// divider, and what it set laid the title bar out again, which is another layout.
///
/// The split is found through the view tree and kept as the delegate's own, because
/// `NavigationSplitView` builds a real `NSSplitViewController` and never makes it a child of the
/// hosting controller: `contentViewController.children` is empty and the controller answers only as
/// `splitView.delegate`.
private struct SplitWatcher: NSViewRepresentable {
    let onLayout: (NSSplitView) -> Void

    func makeNSView(context: Context) -> Watcher { Watcher() }

    func updateNSView(_ view: Watcher, context: Context) {
        view.onLayout = onLayout
        view.report()
    }

    final class Watcher: NSView {
        var onLayout: ((NSSplitView) -> Void)?

        private weak var split: NSSplitView?
        private var watch: (any NSObjectProtocol)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // Retried once, because a scene rebuild can put this view in the window before the
            // split it is watching.
            if !attach() {
                DispatchQueue.main.async { [weak self] in _ = self?.attach() }
            }
        }

        func report() {
            guard let split else { return }
            onLayout?(split)
        }

        private func attach() -> Bool {
            guard let root = window?.contentView, let found = splitView(under: root) else { return false }
            guard found !== split else { return true }
            split = found
            if let watch { NotificationCenter.default.removeObserver(watch) }
            watch = NotificationCenter.default.addObserver(
                forName: NSSplitView.didResizeSubviewsNotification,
                object: found,
                queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.report() } }
            report()
            return true
        }

        private func splitView(under view: NSView) -> NSSplitView? {
            if let split = view as? NSSplitView, split.delegate is NSSplitViewController { return split }
            for subview in view.subviews {
                if let found = splitView(under: subview) { return found }
            }
            return nil
        }
    }
}
