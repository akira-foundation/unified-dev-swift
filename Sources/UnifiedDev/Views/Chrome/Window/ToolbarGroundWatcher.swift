import AppKit
import Core
import SwiftUI

extension View {
    func keepsToolbarGroundAtToolbarHeight() -> some View {
        background(ToolbarGroundWatcher())
    }
}

private struct ToolbarGroundWatcher: NSViewRepresentable {
    func makeNSView(context: Context) -> Watcher { Watcher() }

    func updateNSView(_ view: Watcher, context: Context) { view.correct() }

    final class Watcher: NSView {
        private var observers: [any NSObjectProtocol] = []
        private var watched = NSHashTable<NSView>.weakObjects()

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                observe(name, of: window)
            }
            correct()
        }

        func correct() {
            guard let window, window.styleMask.contains(.fullScreen),
                  let split = window.contentView?.mainSplitView() else { return }
            if !watched.contains(split) {
                watched.add(split)
                observe(NSSplitView.didResizeSubviewsNotification, of: split)
            }
            let band = window.frame.height - window.contentLayoutRect.height
            let inset = window.screen?.safeAreaInsets.top ?? 0
            for ground in split.subviews where Self.isKind("NSTitlebarBackgroundView", ground) {
                watchFrame(of: ground)
                shorten(ground, band: band, inset: inset)
                for pocket in ground.subviews where Self.isKind("NSScrollPocket", pocket) {
                    watchFrame(of: pocket)
                    shorten(pocket, band: band, inset: inset)
                }
            }
        }

        private func shorten(_ view: NSView, band: CGFloat, inset: CGFloat) {
            guard let height = FullScreenToolbarGround.correctedHeight(
                current: view.frame.height, toolbarBand: band, screenTopInset: inset
            ) else { return }
            var frame = view.frame
            if view.superview?.isFlipped == false { frame.origin.y += frame.height - height }
            frame.size.height = height
            view.frame = frame
        }

        private func watchFrame(of view: NSView) {
            guard !watched.contains(view) else { return }
            watched.add(view)
            view.postsFrameChangedNotifications = true
            observe(NSView.frameDidChangeNotification, of: view)
        }

        private func observe(_ name: Notification.Name, of object: AnyObject) {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: object, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.correct() }
            })
        }

        private func stopObserving() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            watched.removeAllObjects()
        }

        private static func isKind(_ name: String, _ view: NSView) -> Bool {
            "\(type(of: view))".contains(name)
        }
    }
}
