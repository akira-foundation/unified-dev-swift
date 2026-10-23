import AppKit
import Foundation
import Core

@MainActor
extension Snapshot {
    static let captureTick = 250

    static var windowWaitTicks: Int {
        CaptureWait.ticks(
            seconds: ProbeHarness.count("--window-wait", or: 10), everyMilliseconds: captureTick
        )
    }

    static func nudgeTheMainWindowOpen() {
        let wanted = WindowTitleMark.decorate(WindowTitleMark.defaultTitle)
        guard let menus = NSApp.mainMenu?.items.compactMap(\.submenu) else { return }
        for menu in menus {
            guard let index = menu.items.firstIndex(where: { $0.title == wanted }) else { continue }
            menu.performActionForItem(at: index)
            return
        }
        let titles = menus.flatMap { menu in menu.items.map { "\(menu.title)/\($0.title)" } }
        FileHandle.standardError.write(Data(
            "no menu item called \(wanted); the menus hold \(titles)\n".utf8
        ))
    }

    static func settleOnScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.screens.first else { return }
        let room = screen.visibleFrame
        let size = CentredWindowPlacement.fitted(window.frame.size, within: room.size)
        window.setFrame(
            CentredWindowPlacement.frame(size: size, around: room, visible: room),
            display: false
        )
    }

    static func revealForTheCapture(_ window: NSWindow, parking: Bool) async -> [NSWindow] {
        guard GalleryOffscreen.isRequested else {
            return parking ? [] : stagedChildren(of: window)
        }
        GalleryOffscreen.stopHiding()
        try? await Task.sleep(for: .milliseconds(50))
        if parking {
            GalleryOffscreen.park(window)
            try? await Task.sleep(for: .milliseconds(150))
        }
        window.alphaValue = 1
        window.contentView?.setNeedsDisplay(window.contentView?.bounds ?? .zero)
        window.display()
        try? await Task.sleep(for: .milliseconds(400))
        guard !parking else { return [] }
        let children = stagedChildren(of: window)
        for child in children { child.alphaValue = 1 }
        try? await Task.sleep(for: .milliseconds(250))
        return children
    }

    static func stagedChildren(of window: NSWindow) -> [NSWindow] {
        NSApp.windows.filter {
            $0 !== window && $0.parent === window && $0.isVisible
                && WindowComposite.staged(
                    child: $0.frame, number: $0.windowNumber, with: window.frame
                )
        }
    }
}
