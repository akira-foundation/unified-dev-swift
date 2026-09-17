import AppKit
import Core

@MainActor
enum WindowCloseShortcut {
    private static let attempts = 40
    private static let spacing: TimeInterval = 0.1
    private static var monitor: Any?

    static func apply() {
        watchForTheKey()
        apply(remaining: attempts)
        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil
        ) { _ in
            RunLoop.main.perform(inModes: [.eventTracking, .default, .common]) {
                MainActor.assumeIsolated {
                    guard let item = closeItem() else { return }
                    item.keyEquivalent = "w"
                    item.keyEquivalentModifierMask = [.command, .shift]
                    item.menu?.itemChanged(item)
                }
            }
        }
    }

    private static func watchForTheKey() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let stroke = stroke(for: event) else { return event }
            return MainActor.assumeIsolated { closeKeyWindow(on: stroke) } ? nil : event
        }
    }

    private static func stroke(for event: NSEvent) -> WindowDismissal.Stroke? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == escapeKeyCode { return modifiers.isEmpty ? .escape : nil }

        guard event.charactersIgnoringModifiers?.lowercased() == "w" else { return nil }
        if modifiers == [.command, .shift] { return .shiftCommandW }
        if modifiers == [.command] { return .commandW }
        return nil
    }

    private static let escapeKeyCode: UInt16 = 53

    private static func closeKeyWindow(on stroke: WindowDismissal.Stroke) -> Bool {
        guard let window = NSApp.keyWindow,
              WindowDismissal.closes(stroke, WindowRoles.target(window))
        else { return false }
        window.performClose(nil)
        return true
    }

    private static func apply(remaining: Int) {
        if applyOnce() || remaining <= 1 { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + spacing) {
            apply(remaining: remaining - 1)
        }
    }

    private static func applyOnce() -> Bool {
        guard let item = closeItem() else { return false }
        guard item.keyEquivalentModifierMask != [.command, .shift] else { return true }
        item.keyEquivalent = "w"
        item.keyEquivalentModifierMask = [.command, .shift]
        return true
    }

    private static func closeItem() -> NSMenuItem? {
        for top in NSApp.mainMenu?.items ?? [] {
            for item in top.submenu?.items ?? []
            where item.action == #selector(NSWindow.performClose(_:)) {
                return item
            }
        }
        return nil
    }
}
