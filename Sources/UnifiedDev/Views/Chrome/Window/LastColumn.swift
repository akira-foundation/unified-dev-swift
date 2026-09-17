import AppKit
import SwiftUI

extension View {
    func collapsesLastColumn(when isEmpty: Bool) -> some View {
        background(SplitWatcher { split in
            guard let controller = split.delegate as? NSSplitViewController,
                  controller.splitViewItems.count >= 3, let last = controller.splitViewItems.last,
                  last.isCollapsed != isEmpty else { return }
            last.isCollapsed = isEmpty
        })
    }
}

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
        private weak var separator: NSView?
        private var watch: (any NSObjectProtocol)?
        private var frames: (any NSObjectProtocol)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            if !attach() {
                DispatchQueue.main.async { [weak self] in _ = self?.attach() }
            }
        }

        func report() {
            guard let split else { return }
            watchSeparator()
            onLayout?(split)
        }

        private func watchSeparator() {
            guard let found = separatorView(), found !== separator else { return }
            separator = found
            found.postsFrameChangedNotifications = true
            if let frames { NotificationCenter.default.removeObserver(frames) }
            frames = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: found,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let split = self.split else { return }
                    self.onLayout?(split)
                }
            }
        }

        private func separatorView() -> NSView? {
            guard let frame = window?.contentView?.superview else { return nil }
            var found: NSView?
            func walk(_ view: NSView) {
                if found == nil, "\(type(of: view))".contains("SeparatorToolbarItemView") { found = view }
                for sub in view.subviews where found == nil { walk(sub) }
            }
            for sub in frame.subviews where found == nil && "\(type(of: sub))".contains("Titlebar") { walk(sub) }
            return found
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
