import AppKit
import SwiftUI

enum SettingsWindow {
    static let id = "settings"

    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(#selector(NSApplication.arrangeInFront(_:)), to: nil, from: nil)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains(id) == true }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu,
              let index = appMenu.items.firstIndex(where: { $0.title.hasPrefix("Settings") })
        else { return }
        appMenu.performActionForItem(at: index)
    }
}
