#if DEBUG
import AppKit
import SwiftUI
import Core

@MainActor
enum MenuProbe {
    static var isRequested: Bool {
        CommandLine.arguments.contains("--menu-probe")
    }

    private static func value(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    private static var outputPath: String {
        value(for: "--menu-probe") ?? (NSTemporaryDirectory() + "unifieddev-menu.png")
    }

    private enum Part: String {
        case menu
        case kinds
        case terminal
        case terminalKinds
        case browser
        case row
        case colour
        case worktree
        case project
        case projectHidden
        case filter
        case diffScope
    }

    private static var part: Part {
        value(for: "--menu-part").flatMap(Part.init(rawValue:)) ?? .menu
    }

    static func schedule() {
        Task { @MainActor in
            Snapshot.applyRequestedAppearance()
            try? await Task.sleep(for: .seconds(3))
            var model: AppModel?
            if part == .row || part == .colour || part == .project || part == .projectHidden {
                let fresh = AppModel()
                await fresh.bootstrap()
                if let workspace = fresh.workspaces.first {
                    await fresh.model(for: workspace).reloadSettings()
                }
                model = fresh
            }
            if part == .diffScope {
                scopeModel = await preparedScopeModel()
            }
            if part == .browser {
                await runBrowser()
                return
            }
            run(model: model)
        }
    }

    private static func run(model: AppModel?) {
        guard let window = NSApp.windows.first(where: {
            $0.isVisible && $0.contentView != nil && $0.parent == nil && $0.styleMask.contains(.titled)
        }) else {
            fail("no window to open a menu from")
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let menu = build(model: model)

        let origin = NSPoint(x: window.frame.minX + 260, y: window.frame.maxY - 220)

        for _ in 0..<6 where !capturedOutput {
            let timer = after(0.4) {
                capturedOutput = capture(to: outputPath)
                menu.cancelTracking()
            }
            present(menu, at: origin, in: window)
            timer.invalidate()
        }

        guard capturedOutput else { fail("the menu would not stay open long enough to photograph") }
        print(outputPath)
        exit(0)
    }

    private static func present(_ menu: NSMenu, at origin: NSPoint, in window: NSWindow) {
        guard part == .terminal, let pane = terminalPane, let content = window.contentView else {
            menu.popUp(positioning: nil, at: origin, in: nil)
            return
        }

        if pane.superview == nil {
            pane.frame = content.bounds
            content.addSubview(pane)
        }

        let point = NSPoint(x: 260, y: content.bounds.height - 220)
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else { fail("could not build a right click to open the terminal's menu with") }

        pane.rightMouseDown(with: event)
    }

    private static let terminalPane: AppTerminalView? = {
        guard MenuProbe.part == .terminal else { return nil }
        return AppTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }()

    private static func build(model: AppModel?) -> NSMenu {
        switch part {
        case .menu:
            NSHostingMenu(rootView: CenterPaneMenu(isSplit: true, split: { _, _ in }, close: {}))
        case .kinds:
            NSHostingMenu(rootView: PaneKindItems { _ in })
        case .terminal:
            terminalMenu()
        case .terminalKinds:
            terminalSplitKinds()
        case .browser:
            NSMenu()
        case .row, .colour:
            workspaceMenu(model: model)
        case .project, .projectHidden:
            projectMenu(model: model)
        case .filter:
            NSHostingMenu(rootView: SidebarFilterMenuItems(
                filter: .constant(.all), showsHiddenProjects: .constant(true), hiddenCount: 2
            ))
        case .worktree:
            NSHostingMenu(rootView: worktreeItems)
        case .diffScope:
            NSHostingMenu(rootView: DiffScopeMenuItems(model: requiredScopeModel))
        }
    }

    private static func terminalMenu() -> NSMenu {
        let menu = TerminalPaneMenu.make(canClose: true, isZoomed: false) { _ in }
        terminalPane?.onContextMenu = { menu }
        return menu
    }

    private static func terminalSplitKinds() -> NSMenu {
        let menu = TerminalPaneMenu.make(canClose: true, isZoomed: false) { _ in }
        guard let kinds = menu.items.first?.submenu else {
            fail("the terminal pane menu has no split submenu")
        }
        parentOfKinds = menu
        return kinds
    }

    private static func runBrowser() async {
        guard let window = NSApp.windows.first(where: {
            $0.isVisible && $0.contentView != nil && $0.parent == nil && $0.styleMask.contains(.titled)
        }), let content = window.contentView else {
            fail("no window to open a menu from")
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        let session = BrowserSession(url: "")
        session.webView.paneMenu = {
            NSHostingMenu(rootView: CenterPaneMenu(isSplit: true, split: { _, _ in }, close: {}))
        }
        session.pageView.frame = content.bounds
        content.addSubview(session.pageView)
        session.webView.loadHTMLString(
            "<body style='font:16px -apple-system'><p>Probe page</p></body>",
            baseURL: URL(string: "http://localhost/")
        )
        try? await Task.sleep(for: .seconds(2))

        let point = NSPoint(x: 200, y: content.bounds.height - 200)
        guard let click = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else { fail("could not build a right click to open the page's menu with") }

        for _ in 0..<6 {
            let timer = after(1.2) {
                if capture(to: outputPath) {
                    print(outputPath)
                    exit(0)
                }
            }
            window.sendEvent(click)
            try? await Task.sleep(for: .seconds(3))
            timer.invalidate()
        }

        fail("the page's menu would not stay open long enough to photograph")
    }

    private static var parentOfKinds: NSMenu?

    private static var scopeModel: WorkspaceModel?

    private static var requiredScopeModel: WorkspaceModel {
        guard let scopeModel else { fail("no worktree to read commits from") }
        return scopeModel
    }

    private static func preparedScopeModel() async -> WorkspaceModel {
        let path = value(for: "--menu-project") ?? FileManager.default.currentDirectoryPath
        let app = AppModel()
        let model = WorkspaceModel(
            workspace: Workspace(
                repoID: .new(),
                name: "Probe",
                branch: "probe/menu",
                path: path,
                baseBranch: value(for: "--menu-base") ?? "main"
            ),
            app: app
        )
        scopeApp = app
        await model.refreshChanges()
        return model
    }

    private static var scopeApp: AppModel?

    private static var worktreeItems: WorktreeMenuItems {
        let path = value(for: "--menu-project") ?? FileManager.default.currentDirectoryPath
        return WorktreeMenuItems(
            workspace: Workspace(
                repoID: .new(),
                name: "Probe",
                branch: "probe/menu",
                path: path,
                baseBranch: "main"
            ),
            pullRequest: nil
        )
    }

    private static func projectMenu(model: AppModel?) -> NSMenu {
        guard let model else { fail("no model to read a project out of") }
        let wantsHidden = part == .projectHidden
        guard let repo = model.repos.first(where: { $0.hidden == wantsHidden }) else {
            fail(wantsHidden
                ? "no hidden project in this database to draw a header menu for"
                : "no showing project in this database to draw a header menu for")
        }
        return NSHostingMenu(rootView: ProjectMenuItems(
            repo: repo, onCreateWorkspace: { _ in }, onRename: {}, onRemove: {}
        ).environment(model))
    }

    private static func workspaceMenu(model: AppModel?) -> NSMenu {
        guard let model, let workspace = model.workspaces.first else {
            fail("no workspace in this database to draw a row menu for")
        }
        let menu = NSHostingMenu(
            rootView: WorkspaceMenuItems(workspace: workspace) { _ in }.environment(model)
        )
        guard part == .colour else { return menu }
        guard let submenu = menu.items.first(where: { $0.title == "Colour" })?.submenu else {
            fail("the row menu has no Colour submenu")
        }
        return submenu
    }

    private static var capturedOutput = false

    private static func menuBounds() -> CGRect? {
        let listed = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
        guard let windows = listed as? [[String: Any]] else { return nil }

        let menuLevel = CGWindowLevelForKey(.popUpMenuWindow)
        var union: CGRect?
        for window in windows {
            guard window[kCGWindowOwnerPID as String] as? pid_t == getpid(),
                  let level = window[kCGWindowLayer as String] as? Int, level >= menuLevel,
                  let raw = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: raw), !frame.isEmpty else { continue }
            union = union.map { $0.union(frame) } ?? frame
        }
        return union
    }

    private static func capture(to path: String) -> Bool {
        guard let bounds = menuBounds() else { return false }
        try? FileManager.default.removeItem(atPath: path)

        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = [
            "-x",
            "-R\(Int(bounds.minX)),\(Int(bounds.minY)),\(Int(bounds.width)),\(Int(bounds.height))",
            path,
        ]
        do {
            try capture.run()
        } catch {
            return false
        }
        capture.waitUntilExit()
        return capture.terminationStatus == 0 && FileManager.default.fileExists(atPath: path)
    }

    @discardableResult
    private static func after(
        _ seconds: TimeInterval, _ work: @escaping @MainActor () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated { work() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}
#endif
