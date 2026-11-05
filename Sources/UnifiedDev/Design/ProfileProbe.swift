import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum ProfileProbe {
    private static let flag = "--profile-probe"

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static var directory: String {
        ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-profile")
    }

    private struct Scene {
        var name: String
        var size: CGSize
        var view: AnyView
    }

    private struct SceneBody {
        var view: AnyView
        var size: CGSize
    }

    private static let unified = Profile(
        id: .initial, name: "Unified", folder: "unified", colour: Accent.all[0], symbol: "square.stack.3d.up"
    )
    private static let akira = Profile(
        id: ProfileID("akira"), name: "Akira", folder: "akira", colour: Accent.all[2], symbol: "leaf"
    )
    private static let long = Profile(
        id: ProfileID("long"),
        name: "A client whose name goes on far longer than any sidebar is wide",
        folder: "long",
        colour: Accent.all[3],
        symbol: "building.2"
    )

    private static func run() async {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let missing = ProfileChoices.symbols.filter {
            NSImage(systemSymbolName: $0.name, accessibilityDescription: nil) == nil
        }
        let menu = NSHostingMenu(rootView: items)
        var written = 0
        var wanted = 0
        for scene in scenes(menu: menu) {
            for scheme in [ColorScheme.light, .dark] {
                wanted += 1
                if await shoot(scene, scheme: scheme) { written += 1 }
            }
        }
        report([
            "wrote \(written) of \(wanted)",
            "unknown symbols: \(missing.map(\.name))",
            "switcher height at 200pt: short \(fittingHeight(of: akira, width: 200)), long \(fittingHeight(of: long, width: 200))",
            "menu: \(menu.items.map(describe))",
            "active=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue) "
                + "visibleWindows=\(NSApp.windows.filter(\.isVisible).count)",
        ])
        exit(written == wanted && missing.isEmpty ? 0 : 1)
    }

    private static func report(_ lines: [String]) {
        FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    private static func describe(_ item: NSMenuItem) -> String {
        if item.isSeparatorItem { return "---" }
        let mark = item.image.map { $0.isTemplate ? "template" : "coloured" } ?? "no image"
        return "\(item.title) [\(item.state == .on ? "on" : "off"), \(mark)]"
    }

    private static var items: some View {
        ProfileSwitcherItems(
            profiles: [unified, akira], activeID: akira.id, onSwitch: { _ in }, onNew: {}, onSettings: {}
        )
    }

    private static func switcher(_ profiles: [Profile], active: ProfileID) -> some View {
        ProfileSwitcherBody(
            profiles: profiles, activeID: active, onSwitch: { _ in }, onNew: {}, onSettings: {}
        )
    }

    private static func sidebar(_ profiles: [Profile], active: ProfileID) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: Metrics.gutter) {
                switcher(profiles, active: active)
                SidebarNavRow(title: "Home", icon: "house")
                SidebarNavRow(title: AskConversation.title, icon: PaneGlyph.chat)
                Spacer(minLength: 0)
            }
            .padding(Metrics.gutter)
        )
    }

    private static func fittingHeight(of profile: Profile, width: CGFloat) -> CGFloat {
        let host = NSHostingController(rootView: switcher([unified, profile], active: profile.id))
        return host.sizeThatFits(in: CGSize(width: width, height: 100_000)).height
    }

    private static func sheet(
        _ draft: ProfileDraft, isNew: Bool = false, refusal: ProfileDeletionRefused? = nil
    ) -> SceneBody {
        SceneBody(
            view: AnyView(
                ProfileSheetBody(
                    draft: .constant(draft),
                    isNew: isNew,
                    deletionRefusal: refusal?.sentence,
                    onDelete: {},
                    onCancel: {},
                    onSave: {}
                )
            ),
            size: CGSize(
                width: ProfileSheetBody.width,
                height: isNew ? ProfileSheetBody.newHeight : ProfileSheetBody.editHeight
            )
        )
    }

    private static func menuRows(_ menu: NSMenu) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                ForEach(Array(menu.items.enumerated()), id: \.offset) { _, item in
                    if item.isSeparatorItem {
                        Divider()
                    } else {
                        HStack(spacing: Metrics.spacing) {
                            Image(systemName: item.state == .on ? "checkmark" : "circle.dotted")
                                .opacity(item.state == .on ? 1 : 0)
                            if let image = item.image {
                                Image(nsImage: image)
                            }
                            Text(item.title)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Metrics.gutter)
        )
    }

    private static func statusModule(_ profile: Profile) -> AnyView {
        var content = MenuBarPanelContent.make(MenuBarPanelContent.Input(
            workspaces: [],
            running: [],
            waiting: [],
            runningAgents: 0,
            quotas: [],
            accounts: [:],
            unanswered: [],
            withoutLimits: [],
            lastReported: [:],
            layout: UsageLayout(),
            hold: .none,
            now: Date(timeIntervalSince1970: 1_800_000_000),
            profile: profile
        ))
        content.needsSetup = false
        return AnyView(
            MenuBarStatusModule(content: content, focus: nil, openSettings: {})
                .padding(MenuBarModuleStyle.edge)
        )
    }

    private static func scenes(menu: NSMenu) -> [Scene] {
        var named = ProfileDraft.new(among: [unified])
        named.name = "Client"
        var blank = ProfileDraft(editing: akira)
        blank.name = "  "
        let sidebarSize = CGSize(width: 260, height: 170)
        let sheets: [(String, SceneBody)] = [
            ("sheet-new", sheet(.new(among: [unified, akira]), isNew: true)),
            ("sheet-new-named", sheet(named, isNew: true)),
            ("sheet-unified", sheet(ProfileDraft(editing: unified), refusal: .initial)),
            ("sheet-with-projects", sheet(ProfileDraft(editing: akira), refusal: .hasProjects(count: 2))),
            ("sheet-empty", sheet(ProfileDraft(editing: akira))),
            ("sheet-blank-name", sheet(blank)),
        ]
        return [
            Scene(name: "switcher-two", size: sidebarSize, view: sidebar([unified, akira], active: akira.id)),
            Scene(name: "switcher-long", size: sidebarSize, view: sidebar([unified, long], active: long.id)),
            Scene(name: "switcher-menu", size: CGSize(width: 260, height: 170), view: menuRows(menu)),
            Scene(name: "menubar-header", size: CGSize(width: 360, height: 130), view: statusModule(akira)),
        ] + sheets.map { Scene(name: $0.0, size: $0.1.size, view: $0.1.view) }
    }

    private static func shoot(_ scene: Scene, scheme: ColorScheme) async -> Bool {
        let host = NSHostingController(rootView: scene.view
            .environment(\.colorScheme, scheme)
            .background(Palette.surface)
            .transaction { $0.disablesAnimations = true }
            .frame(width: scene.size.width, height: scene.size.height))
        host.sizingOptions = []
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: scene.size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = host
        host.view.frame = CGRect(origin: .zero, size: scene.size)
        host.view.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(400))
        host.view.displayIfNeeded()
        guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else { return false }
        host.view.cacheDisplay(in: host.view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(filePath: "\(directory)/\(scene.name)-\(scheme).png"))) != nil
    }
}

#endif
