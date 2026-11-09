import AppKit
import Core

@MainActor
enum ToolbarBandProbe {
    private static let harness = ProbeHarness(subject: "toolbar-band")
    static var isRequested: Bool {
        harness.isRequested && PreviewIdentity.isPreview(bundleIdentifier: Bundle.main.bundleIdentifier)
    }

    static func schedule() { Task { @MainActor in await watch() } }

    private static func watch() async {
        let (window, _) = await harness.window()
        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        var report: [String: JSONValue] = [:]
        while true {
            let fullScreen = window.styleMask.contains(.fullScreen)
            let key = stateKey(window, app: app)
            if report[key] == nil {
                try? await Task.sleep(for: .seconds(2))
                guard stateKey(window, app: app) == key else { continue }
                report[key] = read(window, app: app)
                let mode = fullScreen ? "fullScreen" : "windowed"
                if report["tree " + mode] == nil { report["tree " + mode] = tree(window) }
                harness.write(.object(report))
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private static func stateKey(_ window: NSWindow, app: AppModel) -> String {
        let mode = window.styleMask.contains(.fullScreen) ? "fullScreen" : "windowed"
        return "\(mode) | \(app.menuWorkspace?.name ?? "none") | tabs \(WindowToolbar.showsTabs(in: app))"
    }

    private static func tree(_ window: NSWindow) -> JSONValue {
        var rows: [JSONValue] = []
        func walk(_ view: NSView, _ depth: Int) {
            guard depth < 40, rows.count < 700 else { return }
            let rect = view.convert(view.bounds, to: nil)
            let top = window.frame.height - rect.maxY
            if rect.width > 40, rect.height > 0.4, top < 130 {
                rows.append(.object([
                    "kind": .string("\(type(of: view))"),
                    "depth": .integer(depth),
                    "x": .number(Double(rect.minX)),
                    "top": .number(Double(top)),
                    "bottom": .number(Double(window.frame.height - rect.minY)),
                    "width": .number(Double(rect.width)),
                    "alpha": .number(Double(view.alphaValue)),
                    "hidden": .bool(view.isHidden),
                    "safeTop": .number(Double(view.safeAreaInsets.top)),
                ]))
            }
            for sub in view.subviews { walk(sub, depth + 1) }
        }
        if let frame = window.contentView?.superview { walk(frame, 0) }
        return .array(rows)
    }

    private static func screen(_ window: NSWindow) -> JSONValue {
        guard let screen = window.screen else { return .null }
        return .object([
            "safeAreaTop": .number(Double(screen.safeAreaInsets.top)),
            "frameHeight": .number(Double(screen.frame.height)),
        ])
    }

    private static func read(_ window: NSWindow, app: AppModel) -> JSONValue {
        window.layoutIfNeeded()
        var rows: [JSONValue] = []
        func walk(_ view: NSView) {
            guard !view.isHidden, view.alphaValue > 0.01 else { return }
            let name = "\(type(of: view))"
            let rect = view.convert(view.bounds, to: nil)
            if name.contains("TitlebarBackground") || name.contains("ScrollPocket") || name.contains("Separator"), rect.width > 40 {
                rows.append(.object([
                    "kind": .string(name),
                    "x": .number(Double(rect.minX)),
                    "bottom": .number(Double(window.frame.height - rect.minY)),
                ]))
            }
            for sub in view.subviews { walk(sub) }
        }
        if let frame = window.contentView?.superview { walk(frame) }
        return .object([
            "band": .number(Double(window.frame.height - window.contentLayoutRect.height)),
            "showsTabs": .bool(WindowToolbar.showsTabs(in: app)),
            "fullScreen": .bool(window.styleMask.contains(.fullScreen)),
            "screen": screen(window),
            "strip": .array(rows),
        ])
    }
}
