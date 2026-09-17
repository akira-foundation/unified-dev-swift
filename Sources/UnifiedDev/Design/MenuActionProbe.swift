#if DEBUG
import AppKit
import SwiftUI
import Core

@MainActor
enum MenuActionProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--menu-action") }

    static func schedule() {
        setvbuf(stdout, nil, _IONBF, 0)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))

            guard let window = mainWindow else {
                report("no main window; had \(NSApp.windows.map(\.title))")
                exit(1)
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .seconds(1))

            let before = secondaryWindows()
            report("windows before: \(windowTitles())")

            guard let (menu, index) = item(titled: wantedTitle) else {
                report("no \(scope.rawValue) menu carries an item called \(wantedTitle)")
                exit(2)
            }
            report("item: \(menu.items[index].title), enabled \(menu.items[index].isEnabled)")

            menu.performActionForItem(at: index)
            try? await Task.sleep(for: .seconds(2))
            report("windows after: \(windowTitles())")

            let after = secondaryWindows()
            let fresh = after.first { window in !before.contains { $0 === window } }
            report("opened: \(fresh?.title ?? "nothing new")")
            opened = fresh ?? after.first
            report("acting on: \(opened?.title ?? "no window")")

            if let stroke = closingStroke { await close(with: stroke) }
            if let how = hiding { await askAgain(after: how, menu: menu) }
            if wantsReopen { await closeAndAskAgain(menu: menu) }
            exit(0)
        }
    }

    private static func close(with stroke: WindowDismissal.Stroke) async {
        guard let opened else { return report("nothing was opened to press a key at") }
        opened.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .seconds(1))
        report("key window: \(NSApp.keyWindow?.title ?? "none")")

        let escape = stroke == .escape
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: escape ? [] : (stroke == .commandW ? [.command] : [.command, .shift]),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: opened.windowNumber,
            context: nil,
            characters: escape ? "\u{1B}" : "w",
            charactersIgnoringModifiers: escape ? "\u{1B}" : "w",
            isARepeat: false,
            keyCode: escape ? 53 : 13
        ) else { return report("could not build the key press") }

        NSApp.postEvent(event, atStart: true)
        try? await Task.sleep(for: .seconds(2))
        report("after \(stroke.rawValue): windows \(windowTitles())")
    }

    private static var closingStroke: WindowDismissal.Stroke? {
        value(for: "--menu-action-close").flatMap(WindowDismissal.Stroke.init(rawValue:))
    }

    private static func askAgain(after hiding: String, menu: NSMenu) async {
        guard let opened = opened else { return report("nothing was opened to hide") }
        switch hiding {
        case "miniaturize": opened.miniaturize(nil)
        case "orderOut": opened.orderOut(nil)
        default: return report("unknown way of hiding a window: \(hiding)")
        }
        try? await Task.sleep(for: .seconds(2))
        report("hidden by \(hiding): visible \(opened.isVisible), miniaturized \(opened.isMiniaturized)")

        perform(wantedTitle, in: menu)
        try? await Task.sleep(for: .seconds(3))
        report("asked again: visible \(opened.isVisible), miniaturized \(opened.isMiniaturized)")
        report("windows now: \(windowTitles())")
    }

    private static func closeAndAskAgain(menu: NSMenu) async {
        guard let opened = opened else { return report("nothing was opened to close") }
        opened.performClose(nil)
        try? await Task.sleep(for: .seconds(2))
        report("windows after close: \(windowTitles())")

        perform(wantedTitle, in: menu)
        try? await Task.sleep(for: .seconds(3))
        report("windows after asking again: \(windowTitles())")
    }

    private static var opened: NSWindow?

    private static func secondaryWindows() -> [NSWindow] {
        let main = mainWindow
        return NSApp.windows.filter {
            $0.isVisible && $0 !== main && $0.styleMask.contains(.titled) && $0.contentView != nil
        }
    }

    private enum Scope: String {
        case context
        case main
    }

    private static var scope: Scope {
        value(for: "--menu-action-scope").flatMap(Scope.init(rawValue:)) ?? .context
    }

    private static var wantedTitle: String { value(for: "--menu-action") ?? "Project settings…" }
    private static var wantsReopen: Bool { CommandLine.arguments.contains("--menu-action-reopen") }
    private static var hiding: String? { value(for: "--menu-action-hide") }

    private static func item(titled title: String) -> (NSMenu, Int)? {
        switch scope {
        case .main: mainMenuItem(titled: title)
        case .context: contextMenuItem(titled: title)
        }
    }

    private static func mainMenuItem(titled title: String) -> (NSMenu, Int)? {
        for top in NSApp.mainMenu?.items ?? [] {
            guard let submenu = top.submenu else { continue }
            submenu.update()
            if let index = submenu.items.firstIndex(where: { $0.title == title }) {
                return (submenu, index)
            }
        }
        return nil
    }

    private static func contextMenuItem(titled title: String) -> (NSMenu, Int)? {
        guard let content = mainWindow?.contentView else { return nil }
        var matches: [(NSMenu, Int)] = []
        walk(content) { view in
            guard let menu = view.menu else { return }
            menu.update()
            guard let index = menu.items.firstIndex(where: { $0.title == title }) else { return }
            matches.append((menu, index))
        }
        let wanted = value(for: "--menu-action-row").flatMap(Int.init) ?? 0
        return wanted < matches.count ? matches[wanted] : matches.first
    }

    private static func perform(_ title: String, in menu: NSMenu) {
        menu.update()
        guard let index = menu.items.firstIndex(where: { $0.title == title }) else {
            return report("the item is no longer in the menu")
        }
        menu.performActionForItem(at: index)
    }

    private static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.title == "Unified Dev" && $0.contentView != nil }
    }

    private static func windowTitles() -> [String] {
        NSApp.orderedWindows
            .filter { $0.isVisible && $0.contentView != nil }
            .map { "\($0.title.isEmpty ? "<untitled>" : $0.title)\($0.isKeyWindow ? " [key]" : "")" }
    }

    private static func report(_ line: String) {
        print("MENU ACTION: \(line)")
    }

    private static func walk(_ view: NSView, _ visit: (NSView) -> Void) {
        visit(view)
        for subview in view.subviews { walk(subview, visit) }
    }

    private static func value(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}
#endif
