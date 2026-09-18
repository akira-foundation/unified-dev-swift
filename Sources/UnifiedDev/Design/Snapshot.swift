import SwiftUI
import AppKit
import ScreenCaptureKit
import Core

@MainActor
enum Snapshot {
    static var isRequested: Bool {
        CommandLine.arguments.contains("--snapshot")
    }

    private static var directory: String {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count else {
            return NSTemporaryDirectory() + "unifieddev-shots"
        }
        return arguments[index + 1]
    }

    static func refuseWithoutDatabase(flag: String) {
        guard ProcessInfo.processInfo.environment["UD_DB_PATH"] == nil else { return }
        FileHandle.standardError.write(Data(
            "\(flag) captures against a database named by UD_DB_PATH, and refuses to run without one.\n".utf8
        ))
        exit(1)
    }

    static func refuseIfStale(flag: String) {
        #if DEBUG
        let verdict = CaptureFreshness.of(
            builtAt: lastBuildCompleted,
            newestSourceChangeAt: newestSourceChange
        )
        guard let refusal = verdict.refusal(flag: flag) else { return }
        FileHandle.standardError.write(Data((refusal + "\n").utf8))
        exit(1)
        #endif
    }

    private static var lastBuildCompleted: Date? {
        let record = packageRoot.map { $0.appending(path: ".build/build.db") }
        return [modifiedAt(Bundle.main.executableURL), modifiedAt(record)].compactMap { $0 }.max()
    }

    private static var packageRoot: URL? {
        guard let executable = Bundle.main.executableURL else { return nil }
        let root = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path)
        else { return nil }
        return root
    }

    private static var newestSourceChange: Date? {
        guard let root = packageRoot else { return nil }
        let sources = root.appending(path: "Sources")
        guard let walk = FileManager.default.enumerator(
            at: sources, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        var newest: Date?
        for case let url as URL in walk where url.pathExtension == "swift" {
            guard let changed = modifiedAt(url) else { continue }
            if newest.map({ changed > $0 }) ?? true { newest = changed }
        }
        return newest
    }

    private static func modifiedAt(_ url: URL?) -> Date? {
        try? url?.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    static func runAndExit() -> Never {
        refuseWithoutDatabase(flag: "--snapshot")
        refuseIfStale(flag: "--snapshot")
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            await render()
            semaphore.signal()
        }
        while semaphore.wait(timeout: .now()) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        exit(0)
    }

    static func scheduleURLIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--open-url"), index + 1 < arguments.count else {
            return
        }
        guard let url = OpenURLArgument.url(from: arguments[index + 1]) else {
            FileHandle.standardError.write(
                Data("==> --open-url: not a URL, even repaired: \(arguments[index + 1])\n".utf8)
            )
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            NotificationCenter.default.post(name: .unifieddevHandleURL, object: url)
        }
    }

    static func scheduleSetupLogExpansionIfRequested() {
        #if DEBUG
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--expand-setup-log"),
              index + 1 < arguments.count,
              let delay = Double(arguments[index + 1]) else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            NotificationCenter.default.post(name: .unifieddevExpandSetupLog, object: nil)
        }
        #endif
    }

    static func scheduleTerminalWorkspaceIfRequested() {
        #if DEBUG
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--terminal-workspace") else { return }
        let project = index + 1 < arguments.count && !arguments[index + 1].hasPrefix("--")
            ? arguments[index + 1]
            : nil

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            NotificationCenter.default.post(
                name: .unifieddevStartTerminalWorkspace, object: project
            )
        }
        #endif
    }

    static func scheduleNoticeIfRequested() {
        #if DEBUG
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--notice"),
              index + 1 < arguments.count,
              let delay = Double(arguments[index + 1]) else { return }
        let message = index + 2 < arguments.count && !arguments[index + 2].hasPrefix("--")
            ? arguments[index + 2]
            : "Unified Dev named this workspace Describe fade-in animation feel. Its branch is still "
                + "`freekmurze/iyo-sea`, because `freekmurze/fade-animation-feel` is already taken "
                + "by another branch."

        let hold = arguments.firstIndex(of: "--notice-hold")
            .flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
            .map { $0.split(separator: ",").compactMap { Double($0) } }
            .flatMap { $0.count == 2 ? ($0[0], $0[1]) : nil }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            applyRequestedAppearance()
            NotificationCenter.default.post(name: .unifieddevShowNotice, object: message)

            guard let hold else { return }
            try? await Task.sleep(for: .seconds(hold.0))
            NotificationCenter.default.post(name: .unifieddevHoldNotice, object: true)
            try? await Task.sleep(for: .seconds(hold.1))
            NotificationCenter.default.post(name: .unifieddevHoldNotice, object: false)
        }
        #endif
    }

    static func scheduleRunningStateIfRequested() {
        #if DEBUG
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--running"), index + 1 < arguments.count
        else { return }

        let stages = arguments[index + 1]
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { Set($0.split(separator: ",").map { WorkspaceID(String($0)) }) }
        let selected = arguments.firstIndex(of: "--select").map { $0 + 1 }
            .flatMap { $0 < arguments.count ? arguments[$0] : nil }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            applyRequestedAppearance()
            if !isWindowCaptureRequested, let selected {
                OpenWorkspaceNotification.post(WorkspaceID(selected))
                try? await Task.sleep(for: .seconds(2))
            }
            if arguments.contains("--collapse-sidebar") {
                NotificationCenter.default.post(name: .unifieddevToggleSidebar, object: nil)
                try? await Task.sleep(for: .seconds(1))
            }
            for (index, ids) in stages.enumerated() {
                if index > 0 { try? await Task.sleep(for: .seconds(6)) }
                NotificationCenter.default.post(name: .unifieddevCaptureRunning, object: ids)
            }
        }
        #endif
    }

    private static var requestedSidebarWidth: CGFloat? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--sidebar-width"), index + 1 < arguments.count,
              let width = Double(arguments[index + 1])
        else { return nil }

        return width
    }

    private static func firstSplitView(under view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView { return split }
        for subview in view.subviews {
            if let found = firstSplitView(under: subview) { return found }
        }
        return nil
    }

    private static var requestedWindowSize: CGSize? {
        ProbeHarness.value(for: "--window-size").flatMap(ProbeStats.windowSize)
    }

    static var isDrivingTheWindow: Bool {
        isRequested || isWindowCaptureRequested || isGalleryCaptureRequested
            || FrameProbe.isRequested || SwitchProbe.isRequested || ScrollProbe.isRequested
            || ResizeProbe.isRequested || TabProbe.isRequested || ComposerProbe.isRequested
            || TranscriptLayoutProbe.isRequested
            || WelcomeRestartProbe.isRequested
            || CommandLine.arguments.contains("--menu-probe")
    }

    static var isWindowCaptureRequested: Bool {
        CommandLine.arguments.contains("--snapshot-window")
    }

    private static var windowCapturePath: String {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot-window"), index + 1 < arguments.count else {
            return NSTemporaryDirectory() + "unifieddev-window.png"
        }
        return arguments[index + 1]
    }

    static var requestedSettingsTab: SettingsTab? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--settings-tab"), index + 1 < arguments.count else {
            return nil
        }
        let name = arguments[index + 1]
        if name == "models" { return .sessions }
        if name == "approvals" { return .permissions }
        return SettingsTab(rawValue: name)
    }

    private static var requestedAppearance: NSAppearance? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--appearance"), index + 1 < arguments.count
        else { return nil }

        return switch arguments[index + 1] {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    static func applyRequestedAppearance() {
        guard let appearance = requestedAppearance else { return }
        NSApp.appearance = appearance
    }

    static func scheduleWindowCapture() {
        refuseWithoutDatabase(flag: "--snapshot-window")
        refuseIfStale(flag: "--snapshot-window")
        Task { @MainActor in
            let path = windowCapturePath
            applyRequestedAppearance()
            try? await Task.sleep(for: .seconds(3))

            let arguments = CommandLine.arguments
            if let index = arguments.firstIndex(of: "--select"), index + 1 < arguments.count {
                OpenWorkspaceNotification.post(WorkspaceID(arguments[index + 1]))
                try? await Task.sleep(for: .seconds(3))
            }

            if arguments.contains("--new-workspace") {
                NotificationCenter.default.post(name: .udNewWorkspace, object: nil)
                try? await Task.sleep(for: .seconds(2))
            }

            let wantsNewProject = arguments.contains("--new-project")
            if wantsNewProject {
                NotificationCenter.default.post(name: .udNewProject, object: nil)
                try? await Task.sleep(for: .seconds(2))
            }

            var wantsProjectSetup = false
            if let index = arguments.firstIndex(of: "--project-setup"), index + 1 < arguments.count {
                wantsProjectSetup = true
                NotificationCenter.default.post(
                    name: .unifieddevOfferProjectSetup, object: arguments[index + 1]
                )
                try? await Task.sleep(for: .seconds(3))
            }

            let wantsSettings = arguments.contains("--settings")

            let repoSettingsIndex = arguments.firstIndex(of: "--repo-settings")
            let wantsRepoSettings = repoSettingsIndex != nil
            let repoSettingsProject = repoSettingsIndex
                .map { $0 + 1 }
                .flatMap { $0 < arguments.count && !arguments[$0].hasPrefix("--") ? arguments[$0] : nil }

            let wantsAbout = arguments.contains("--about")

            let wantsWelcome = arguments.contains("--welcome")

            var candidate: NSWindow?
            for _ in 0..<40 {
                candidate = capturableWindows().first
                if candidate != nil { break }
                try? await Task.sleep(for: .milliseconds(250))
            }

            if wantsSettings || wantsRepoSettings || wantsAbout || wantsWelcome || wantsNewProject {
                let main = candidate
                candidate = nil
                for _ in 0..<40 {
                    candidate = capturableWindows().first { $0 !== main }
                    if candidate != nil { break }
                    switch (wantsRepoSettings, wantsAbout, wantsWelcome, wantsNewProject) {
                    case (true, _, _, _):
                        NotificationCenter.default.post(
                            name: .unifieddevOpenRepoSettings, object: repoSettingsProject
                        )
                    case (_, true, _, _):
                        openAppMenuItem(titled: "About")
                    case (_, _, true, _):
                        WelcomeWindow.show()
                    case (_, _, _, true):
                        NotificationCenter.default.post(name: .udNewProject, object: nil)
                    default:
                        openSettingsWindow()
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }

            let wantsFeedbackSheet = [
                "--feedback-sheet", "--feedback-logs", "--feedback-problems", "--feedback-sent",
                "--prompt-sheet", "--prompt-problems", "--prompt-sent",
            ].contains(where: arguments.contains)

            if wantsProjectSetup || wantsFeedbackSheet {
                for _ in 0..<20 where candidate?.attachedSheet == nil {
                    try? await Task.sleep(for: .milliseconds(250))
                }
                candidate = candidate?.attachedSheet ?? candidate
            }

            if let index = arguments.firstIndex(of: "--capture-delay"), index + 1 < arguments.count,
               let seconds = Double(arguments[index + 1]) {
                try? await Task.sleep(for: .seconds(seconds))
            }

            guard let window = candidate, let contentView = window.contentView else {
                FileHandle.standardError.write(Data("no window to capture\n".utf8))
                exit(1)
            }

            let content = contentView.superview ?? contentView

            if let size = requestedWindowSize {
                window.setContentSize(size)
                window.layoutIfNeeded()
                try? await Task.sleep(for: .seconds(2))
                window.layoutIfNeeded()
                window.displayIfNeeded()
            }

            if let sidebarWidth = requestedSidebarWidth, let split = firstSplitView(under: content) {
                split.setPosition(sidebarWidth, ofDividerAt: 0)
                try? await Task.sleep(for: .seconds(2))
                window.layoutIfNeeded()
                window.displayIfNeeded()
            }

            if await captureOwnWindow(window, to: path)
                || captureWindowServerImage(windowNumber: window.windowNumber, to: path) {
                print(path)
                exit(0)
            }

            FileHandle.standardError.write(Data(
                "screencapture failed; falling back to an in-process draw, which omits AppKit panes\n".utf8
            ))
            let bounds = content.bounds
            guard let rep = content.bitmapImageRepForCachingDisplay(in: bounds) else {
                FileHandle.standardError.write(Data("could not allocate a bitmap\n".utf8))
                exit(1)
            }
            if let layer = content.layer, let context = NSGraphicsContext(bitmapImageRep: rep) {
                context.cgContext.saveGState()
                if content.isFlipped {
                    context.cgContext.translateBy(x: 0, y: bounds.height)
                    context.cgContext.scaleBy(x: 1, y: -1)
                }
                layer.render(in: context.cgContext)
                context.cgContext.restoreGState()
                context.flushGraphics()
            } else {
                content.cacheDisplay(in: bounds, to: rep)
            }

            guard let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write(Data("could not encode the bitmap\n".utf8))
                exit(1)
            }
            try? png.write(to: URL(fileURLWithPath: path))
            print(path)
            exit(0)
        }
    }

    static var isGalleryCaptureRequested: Bool {
        CommandLine.arguments.contains("--snapshot-gallery")
    }

    static func scheduleGalleryCapture() {
        refuseWithoutDatabase(flag: "--snapshot-gallery")
        refuseIfStale(flag: "--snapshot-gallery")
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot-gallery"),
              index + 1 < arguments.count else {
            FileHandle.standardError.write(Data(
                "--snapshot-gallery needs a directory to write into.\n".utf8
            ))
            exit(1)
        }
        let output = arguments[index + 1]
        let index2 = arguments.firstIndex(of: "--gallery").map { $0 + 1 }
        let named = index2.flatMap { $0 < arguments.count ? arguments[$0] : nil }
        let choice = Snapshot.gallery(named: named)

        Task { @MainActor in
            try? FileManager.default.createDirectory(
                atPath: output, withIntermediateDirectories: true
            )
            try? await Task.sleep(for: .seconds(3))

            let app = AppModel()
            let size = choice.size
            for name in ["light", "dark"] {
                let window = NSWindow(
                    contentRect: NSRect(origin: .zero, size: size),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                window.title = choice.title
                window.appearance = NSAppearance(named: name == "dark" ? .darkAqua : .aqua)
                window.contentView = NSHostingView(
                    rootView: choice.view(app)
                        .frame(width: size.width, height: size.height)
                        .background(Palette.windowBackground)
                )
                window.center()
                if choice.needsFocus {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    window.orderFrontRegardless()
                }
                try? await Task.sleep(for: .seconds(2))

                let path = "\(output)/\(choice.name)-\(name).png"
                if captureWindowServerImage(windowNumber: window.windowNumber, to: path) {
                    print(path)
                } else {
                    FileHandle.standardError.write(Data(
                        "screencapture failed for \(path); screen recording may not be granted\n".utf8
                    ))
                }
                window.orderOut(nil)
            }
            exit(0)
        }
    }

    private static func captureOwnWindow(_ window: NSWindow, to path: String) async -> Bool {
        do {
            let content = try await SCShareableContent.currentProcess
            guard let target = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) })
            else { return false }
            let filter = SCContentFilter(desktopIndependentWindow: target)
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.frame.width * window.backingScaleFactor)
            configuration.height = Int(window.frame.height * window.backingScaleFactor)
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { return false }
            try png.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            FileHandle.standardError.write(Data("Own-window capture failed: \(error.localizedDescription)\n".utf8))
            return false
        }
    }

    private static func captureWindowServerImage(windowNumber: Int, to path: String) -> Bool {
        try? FileManager.default.removeItem(atPath: path)

        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-o", "-x", "-l\(windowNumber)", path]
        do {
            try capture.run()
        } catch {
            return false
        }
        capture.waitUntilExit()

        guard capture.terminationStatus == 0 else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int ?? 0
        return size > 0
    }

    @MainActor
    private static func capturableWindows() -> [NSWindow] {
        NSApp.windows.filter {
            $0.isVisible && $0.contentView != nil && $0.parent == nil
                && $0.styleMask.contains(.titled)
        }
    }

    private static func openSettingsWindow() {
        openAppMenuItem(titled: "Settings")
    }

    private static func openAppMenuItem(titled prefix: String) {
        if !CommandLine.arguments.contains("--background-capture") {
            NSApp.activate(ignoringOtherApps: true)
        }
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }
        guard let index = appMenu.items.firstIndex(where: { $0.title.hasPrefix(prefix) })
        else { return }
        appMenu.performActionForItem(at: index)
    }

    private static func render() async {
        let output = directory
        try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

        let model = await seededModel()

        let report = await AgentQuotaSources.report()

        let scenes: [(String, AnyView, CGSize)] = [
            ("sidebar", AnyView(SidebarView().frame(width: 260, height: 620)), CGSize(width: 260, height: 620)),
            ("home", AnyView(HomeView().frame(width: 900, height: 620)), CGSize(width: 900, height: 620)),
            ("components", AnyView(ComponentGallery().frame(width: 640, height: 700)), CGSize(width: 640, height: 700)),
            ("permission", AnyView(PermissionSnapshotGallery().frame(width: 720, height: 1560)), CGSize(width: 720, height: 1560)),
            ("plan-approval", AnyView(PlanApprovalSnapshotGallery()), CGSize(width: 720, height: 1100)),
            ("tool-rows", AnyView(ToolRowSnapshotGallery().frame(width: 800, height: 1_020)), CGSize(width: 800, height: 1_020)),
            ("check-runs", AnyView(CheckRunSnapshotGallery()), CGSize(width: 420, height: 1000)),
            ("retries", AnyView(RetrySnapshotGallery().frame(width: 860, height: 1020)), CGSize(width: 860, height: 1020)),
            ("running-glyph-still", AnyView(RunningGlyphGallery()), Gallery.runningGlyph.size),
            ("status-column", AnyView(StatusColumnGallery()), Gallery.statusColumn.size),
            ("activity-rule-still", AnyView(ActivityRuleGallery()), Gallery.activityRule.size),
            (
                "sidebar-indent",
                AnyView(SidebarIndentGallery(app: model)),
                Gallery.sidebarIndent.size
            ),
            ("running-colour", AnyView(RunningColourGallery()), Gallery.runningColour.size),

            (
                "limits",
                AnyView(UsagePanelSnapshot(quotas: report.quotas, accounts: report.accounts, now: Date())),
                CGSize(width: MenuBarPanelPlacement.width, height: 900)
            ),
            (
                "limits-states",
                AnyView(
                    LimitsStateGallery()
                        .background(Color(nsColor: .windowBackgroundColor))
                ),
                CGSize(width: MenuBarPanelPlacement.width, height: 2400)
            ),
        ]

        for appearanceName in ["light", "dark"] {
            let appearance = NSAppearance(named: appearanceName == "dark" ? .darkAqua : .aqua)!
            NSApp?.appearance = appearance

            for (name, view, size) in scenes {
                var rendered: Data?
                appearance.performAsCurrentDrawingAppearance {
                let renderer = ImageRenderer(
                    content: view
                        .environment(model)
                        .environment(\.colorScheme, appearanceName == "dark" ? .dark : .light)
                        .frame(width: size.width, height: size.height)
                        .background(Palette.windowBackground)
                )
                renderer.scale = 2

                if let image = renderer.nsImage,
                   let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff) {
                    rendered = bitmap.representation(using: .png, properties: [:])
                }
                }

                guard let png = rendered else {
                    FileHandle.standardError.write(Data("could not render \(name)\n".utf8))
                    continue
                }
                let path = "\(output)/\(name)-\(appearanceName).png"
                try? png.write(to: URL(fileURLWithPath: path))
                print(path)
            }
        }
    }

    private static func seededModel() async -> AppModel {
        let model = AppModel()
        await model.bootstrap()
        return model
    }
}

private struct ComponentGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("Text") {
                Text("Title, semibold body").font(Typo.title)
                Text("Body, the default reading size").font(Typo.body)
                Text("Label, one step down").font(Typo.label).foregroundStyle(Palette.textSecondary)
                Text("Caption, for metadata").font(Typo.caption).foregroundStyle(Palette.textTertiary)
                Text("let code = \"monospaced\"").font(Typo.code)
            }

            group("Chips and stats") {
                HStack(spacing: 6) {
                    Chip(text: "Read", systemImage: "doc.text")
                    Chip(text: "Ticket.php", monospaced: true)
                    Chip(text: "opus", systemImage: "sparkle", tint: Palette.accent)
                    DiffStatLabel(additions: 118, deletions: 4)
                    DiffStatLabel(additions: 2_800, deletions: 608)
                }
            }

            group("Rows") {
                VStack(spacing: 2) {
                    galleryRow("Selected row", selected: true, hovered: false)
                    galleryRow("Hovered row", selected: false, hovered: true)
                    galleryRow("Plain row", selected: false, hovered: false)
                }
            }

            group("Buttons") {
                HStack(spacing: 8) {
                    Button("Primary") {}.buttonStyle(.borderedProminent).controlSize(.large)
                    Button("Secondary") {}.buttonStyle(.bordered).controlSize(.large)
                    Button("Borderless") {}.buttonStyle(.borderless)
                }
            }

            group("Pull request badge") {
                HStack(spacing: 8) {
                    PullRequestBadge(number: 2_631, title: "Fix merge conflicts", url: "", tint: nil)
                    PullRequestBadge(
                        number: 42, title: "Ready to merge",
                        url: "", tint: Palette.positive
                    )
                    PullRequestBadge(
                        number: 7, title: "Checks failing",
                        url: "", tint: Palette.negative
                    )
                }
            }

            group("Inspector folder toggle") {
                HStack(spacing: 8) {
                    Button { } label: { Image(systemName: "folder") }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                    Button { } label: { Image(systemName: "folder") }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                }
            }

            group("State") {
                HStack(spacing: 14) {
                    HStack(spacing: 5) { ActivityDot(isActive: true); Text("Running").font(Typo.label) }
                    HStack(spacing: 5) { ActivityDot(isActive: false); Text("Idle").font(Typo.label) }
                    Text("Positive").font(Typo.label).foregroundStyle(Palette.positive)
                    Text("Negative").font(Typo.label).foregroundStyle(Palette.negative)
                    Text("Warning").font(Typo.label).foregroundStyle(Palette.warning)
                }
            }

            group("Diff tints") {
                VStack(spacing: 0) {
                    Text("+    let added = true")
                        .font(Typo.code)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                        .background(Palette.diffAddBackground)
                    Text("-    let removed = false")
                        .font(Typo.code)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                        .background(Palette.diffDeleteBackground)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Palette.surface)
    }

    private func galleryRow(_ title: String, selected: Bool, hovered: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch").font(Typo.caption)
            Text(title).font(Typo.body)
            Spacer()
            DiffStatLabel(additions: 12, deletions: 3)
        }
        .padding(.horizontal, 8)
        .frame(height: Metrics.rowHeight)
        .rowBackground(isSelected: selected, isHovered: hovered)
    }

    @ViewBuilder
    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)
            content()
        }
    }
}

extension Notification.Name {
    static let unifieddevCaptureRunning = Notification.Name("unifieddev.captureRunning")

    static let unifieddevExpandSetupLog = Notification.Name("unifieddev.expandSetupLog")

    static let unifieddevShowNotice = Notification.Name("unifieddev.showNotice")

    static let unifieddevHoldNotice = Notification.Name("unifieddev.holdNotice")
}

extension View {
    func acceptsCaptureRunningState(_ app: AppModel) -> some View {
        #if DEBUG
        return onReceive(NotificationCenter.default.publisher(for: .unifieddevCaptureRunning)) { note in
            guard let ids = note.object as? Set<WorkspaceID> else { return }
            app.setRunningWorkspaceIDsForCapture(ids)
        }
        #else
        return self
        #endif
    }

    func acceptsCaptureSetupLogExpansion(_ expand: @escaping @MainActor () -> Void) -> some View {
        #if DEBUG
        return onReceive(NotificationCenter.default.publisher(for: .unifieddevExpandSetupLog)) { _ in
            expand()
        }
        #else
        return self
        #endif
    }

    func acceptsCaptureNotice(_ app: AppModel) -> some View {
        #if DEBUG
        return onReceive(NotificationCenter.default.publisher(for: .unifieddevShowNotice)) { note in
            guard let message = note.object as? String else { return }
            app.notice = Notice(message: message)
        }
        #else
        return self
        #endif
    }

    func acceptsCaptureNoticeHold(_ hold: @escaping @MainActor (Bool) -> Void) -> some View {
        #if DEBUG
        return onReceive(NotificationCenter.default.publisher(for: .unifieddevHoldNotice)) { note in
            guard let held = note.object as? Bool else { return }
            hold(held)
        }
        #else
        return self
        #endif
    }
}

private struct LimitsStateGallery: View {
    private static let now = Date(timeIntervalSince1970: 1_787_500_000)
    private static let week: TimeInterval = 604_800

    private static func quota(
        _ provider: AgentKind,
        _ window: QuotaWindow,
        _ used: Double?,
        after resets: TimeInterval?
    ) -> AgentQuota {
        AgentQuota(
            provider: provider,
            window: window,
            measure: used.map { .fraction($0) } ?? .unknown,
            resetsAt: resets.map { now.addingTimeInterval($0) },
            observedAt: now
        )
    }

    private static let scenes: [(String, [AgentQuota], QuotaFreshness)] = [
        ("Quiet", [
            quota(.claudeCode, .named("five_hour"), 0.12, after: 15_600),
            quota(.claudeCode, .named("seven_day"), 0.09, after: week * 0.85),
            quota(.codex, .lasting(week, key: "primary"), 0.03, after: week * 0.7),
        ], .current),
        ("The ramp, and the owner's own figures", [
            quota(.claudeCode, .named("five_hour"), 0.04, after: 3900),
            quota(.claudeCode, .named("seven_day"), 0.60, after: week * 0.535),
            quota(
                .claudeCode,
                QuotaWindow(key: "seven_day_model_fable", label: "Week (Fable)", duration: week),
                0.71,
                after: week * 0.535
            ),
            quota(.codex, .lasting(week, key: "primary"), 0, after: week * 0.9),
        ], .current),
        ("Nobody measured the session window", [
            quota(.claudeCode, .named("five_hour"), nil, after: 9600),
            quota(.claudeCode, .named("seven_day"), 0.44, after: week * 0.6),
            quota(.codex, .lasting(week, key: "primary"), 0, after: week * 0.9),
        ], .current),
        ("Codex absent, and one window spent", [
            quota(.claudeCode, .named("five_hour"), 1, after: 2900),
            quota(.claudeCode, .named("seven_day"), 0.88, after: week * 0.3),
        ], .stale(11_000)),
        ("Model scoped rows and extra usage, both present", [
            quota(.claudeCode, .named("five_hour"), 0.22, after: 7900),
            quota(.claudeCode, .named("seven_day"), 0.66, after: week * 0.6),
            quota(
                .claudeCode,
                QuotaWindow(key: "seven_day_model_opus", label: "Week (Opus)", duration: week),
                0.93,
                after: week * 0.6
            ),
            AgentQuota(
                provider: .claudeCode,
                window: QuotaWindow(key: "extra_usage", label: "Extra usage"),
                measure: .counted(used: 17.2, limit: 50, unit: "USD"),
                resetsAt: nil,
                observedAt: now
            ),
            quota(.codex, .lasting(week, key: "primary"), 0.58, after: week * 0.45),
        ], .current),
        ("Nothing reported at all", [], .current),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.scenes.enumerated()), id: \.offset) { _, scene in
                Text(scene.0)
                    .font(Font(NSFont.menuFont(ofSize: 0)).weight(.semibold))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .padding(.leading, 22)
                    .padding(.top, 20)
                UsagePanelSnapshot(quotas: scene.1, now: Self.now)
            }
        }
        .padding(.bottom, 20)
    }
}

private struct UsagePanelSnapshot: View {
    let quotas: [AgentQuota]
    var accounts: [AgentAccount] = []
    let now: Date

    var body: some View {
        let byProvider = Dictionary(accounts.map { ($0.provider, $0) }, uniquingKeysWith: { first, _ in first })
        let metrics = UsageCatalogue.metrics(quotas: quotas, accounts: byProvider, at: now)
        GlassEffectContainer(spacing: MenuBarModuleStyle.gap) {
            VStack(spacing: MenuBarModuleStyle.gap) {
                ForEach(UsageMenuModel.shared.layout.sections(for: metrics)) { section in
                    MenuBarProviderModule(
                        provider: MenuBarPanelContent.Provider(kind: section.provider, reading: .measured),
                        section: section,
                        plan: byProvider[section.provider]?.plan,
                        options: UsageMenuModel.shared.options,
                        now: now,
                        retry: {},
                        toggleFold: {}
                    )
                }
            }
        }
        .padding(MenuBarModuleStyle.gap)
        .frame(width: MenuBarPanelPlacement.width)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
