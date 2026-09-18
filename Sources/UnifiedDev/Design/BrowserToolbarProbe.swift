import SwiftUI
import AppKit
import Core

@MainActor
enum BrowserToolbarProbe {
    private static let harness = ProbeHarness(subject: "browser-toolbar")

    static var isRequested: Bool { harness.isRequested }

    static func schedule() {
        Task { @MainActor in
            let (window, _) = await harness.window()
            guard let app = ProbeHarness.appModel,
                  let workspace = app.repos.flatMap({ app.workspaces(in: $0) }).first(where: { $0.name == "Lighthouse" })
            else { harness.fail("no Lighthouse workspace; open the preview with Tools/scenarios/browser-toolbar.json first") }
            OpenWorkspaceNotification.post(workspace.id)
            try? await Task.sleep(for: .seconds(2))
            guard let model = app.selectedModel,
                  let tab = CenterTabStore.shared.tabs(for: model.workspace.id).first(where: { $0.kind == .browser }),
                  let frameView = window.contentView?.superview
            else { harness.fail("no browser tab in Lighthouse") }
            WorkspaceTabsStore.shared.select(.tool(tab.id), in: model)
            try? await Task.sleep(for: .seconds(4))

            guard let bar = toolbarFrame(in: frameView) else { harness.fail("no toolbar drawn") }
            let session = CenterTabStore.shared.liveBrowser(for: tab)
            let inset = 4 + BrowserToolbarButton.width / 2

            click(window, at: NSPoint(x: bar.minX + inset + BrowserToolbarButton.width * 2, y: bar.midY))
            var reloaded = false
            for _ in 0..<100 {
                if session?.isLoading == true { reloaded = true }
                try? await Task.sleep(for: .milliseconds(3))
            }

            let windows = NSApp.windows.count
            click(window, at: NSPoint(x: bar.maxX - inset - BrowserToolbarButton.width * 4, y: bar.midY))
            try? await Task.sleep(for: .seconds(1))
            let opened = NSApp.windows.count > windows

            harness.write(.object([
                "reloadStartsALoad": .bool(reloaded),
                "viewportOpensItsPopover": .bool(opened),
            ]), echo: true)
            exit(reloaded && opened ? 0 : 1)
        }
    }

    private static func toolbarFrame(in root: NSView) -> CGRect? {
        let frame = root.convert(root.bounds, to: nil)
        if "\(type(of: root))".contains("GraphicsView"), frame.height == 30, frame.width > 300 { return frame }
        return root.subviews.lazy.compactMap { toolbarFrame(in: $0) }.first
    }

    private static func click(_ window: NSWindow, at point: NSPoint) {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ) {
                window.sendEvent(event)
            }
        }
    }
}
