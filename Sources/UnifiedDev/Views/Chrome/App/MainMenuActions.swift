import AppKit
import Core

@MainActor
enum MainMenuActions {
    static func runnable() -> Set<MenuBarAction> {
        var byTitle: [String: MenuBarAction] = [:]
        for row in MenuBarCatalogue.commands {
            byTitle[row.title] = row.action
            if let alternate = row.alternateTitle { byTitle[alternate] = row.action }
        }

        var found: Set<MenuBarAction> = []
        for top in NSApp.mainMenu?.items ?? [] {
            guard let submenu = top.submenu else { continue }
            submenu.update()
            for item in submenu.items {
                guard let action = byTitle[item.title], item.isEnabled, !item.hasSubmenu else {
                    continue
                }
                found.insert(action)
            }
        }
        return found
    }

    @discardableResult
    static func perform(_ action: MenuBarAction) -> Bool {
        guard let found = item(for: action) else { return false }
        let item = found.menu.items[found.index]
        guard item.isEnabled, !item.hasSubmenu else { return false }
        found.menu.performActionForItem(at: found.index)
        return true
    }

    private static func item(for action: MenuBarAction) -> (menu: NSMenu, index: Int)? {
        let row = MenuBarCatalogue[action]
        let titles = [row.title, row.alternateTitle].compactMap { $0 }
        for top in NSApp.mainMenu?.items ?? [] {
            guard let submenu = top.submenu else { continue }
            submenu.update()
            if let index = submenu.items.firstIndex(where: { titles.contains($0.title) }) {
                return (submenu, index)
            }
        }
        return nil
    }
}
