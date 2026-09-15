import AppKit
import SwiftUI

/// The settings window's identity, and the one way to open it from outside a view.
///
/// It is an ordinary `Window` rather than the `Settings` scene: that scene insets its content in a
/// container with a rim of its own, which made this window read as a different app from the main
/// one. See `UnifiedDevApp`.
enum SettingsWindow {
    static let id = "settings"

    /// Brings the window up, from a menu or from anywhere else that is not a view.
    ///
    /// `NSApp.sendAction` is the answer usually given for the old `Settings` scene and it never
    /// worked here, because SwiftUI installed that action on the menu item rather than on the
    /// responder chain. A window with an id needs none of that.
    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(#selector(NSApplication.arrangeInFront(_:)), to: nil, from: nil)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains(id) == true }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        // Not open yet: the menu item the app declares is what creates it. Matched by prefix,
        // because it carries an ellipsis.
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu,
              let index = appMenu.items.firstIndex(where: { $0.title.hasPrefix("Settings") })
        else { return }
        appMenu.performActionForItem(at: index)
    }
}
