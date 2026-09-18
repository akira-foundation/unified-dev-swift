import AppKit
import SwiftUI
import Core

@MainActor
final class MenuBarPanelController {
    private let window = MenuBarPanelWindow()
    private var monitors: [Any] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private(set) var isOpen = false
    private var anchor = CGRect.zero
    private var visible = CGRect.zero
    private var contentHeight: CGFloat = 1
    private weak var button: NSStatusBarButton?

    init(onCommand: @escaping (MenuBarPanelKey.Command) -> Void) {
        window.onCommand = onCommand
    }

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
        isOpen = true
        DispatchQueue.main.async { [weak self, weak button] in
            guard self?.isOpen == true else { return }
            button?.highlight(true)
        }
        watchForClicksOutside()
        watchForLeaving()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        window.orderOut(nil)
        button?.highlight(false)
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        for (centre, observer) in observers { centre.removeObserver(observer) }
        observers = []
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isOpen else { return }
            self.window.contentView = nil
        }
    }

    private func watchForLeaving() {
        let workspace = NSWorkspace.shared.notificationCenter
        let local = NotificationCenter.default
        let leaving: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didActivateApplicationNotification),
            (workspace, NSWorkspace.activeSpaceDidChangeNotification),
            (local, NSApplication.didHideNotification),
        ]
        for (centre, name) in leaving {
            let observer = centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            }
            observers.append((centre, observer))
        }
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
