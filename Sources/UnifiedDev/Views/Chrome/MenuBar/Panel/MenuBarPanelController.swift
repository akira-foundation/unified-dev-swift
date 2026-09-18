import AppKit
import SwiftUI
import Core

@MainActor
final class MenuBarPanelController {
    private let window = MenuBarPanelWindow()
    private var monitors: [Any] = []
    private var anchor = CGRect.zero
    private var visible = CGRect.zero
    private var contentHeight: CGFloat = 1
    private weak var button: NSStatusBarButton?

    init(onCommand: @escaping (MenuBarPanelKey.Command) -> Void) {
        window.onCommand = onCommand
    }

    var isOpen: Bool { window.isVisible }

    func open(_ content: AnyView, below button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen ?? NSScreen.main else { return }
        self.button = button
        anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        visible = screen.visibleFrame
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        place()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(host)
        button.highlight(true)
        watchForClicksOutside()
    }

    func close() {
        guard window.isVisible else { return }
        window.orderOut(nil)
        window.contentView = nil
        button?.highlight(false)
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
    }

    func contentHeightChanged(_ height: CGFloat) {
        guard abs(height - contentHeight) > 0.5 else { return }
        contentHeight = height
        place()
    }

    private func place() {
        let placement = MenuBarPanelPlacement.place(anchor: anchor, visible: visible, contentHeight: contentHeight)
        window.setFrame(placement.frame, display: true)
    }

    private func watchForClicksOutside() {
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, event.window !== self.window, event.window !== self.button?.window else { return }
                self.close()
            }
            return event
        }) {
            monitors.append(local)
        }
    }
}
