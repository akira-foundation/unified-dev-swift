import SwiftUI
import AppKit
import Core

struct SpendScreenWindow: Scene {
    let model: AppModel

    static let id = "spend"

    var body: some Scene {
        Window(SpendLines.title, id: Self.id) {
            SpendScreenView()
                .environment(model)
                .windowRole(.reading)
        }
        .defaultSize(width: 880, height: 620)
        .defaultPosition(.center)
    }

    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.contains(id) == true }) {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let menu = NSApp.mainMenu?.items.first?.submenu,
              let index = menu.items.firstIndex(where: { $0.title == SpendLines.title })
        else { return }
        menu.performActionForItem(at: index)
    }
}
