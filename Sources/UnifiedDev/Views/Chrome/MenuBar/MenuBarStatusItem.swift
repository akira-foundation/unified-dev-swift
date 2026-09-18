import AppKit
import SwiftUI
import Core

@MainActor
final class MenuBarStatusItem: NSObject, NSMenuDelegate {
    static let shared = MenuBarStatusItem()

    static let settingKey = "menuBar.showsStatusItem"

    static let isOnByDefault = true

    private var item: NSStatusItem?
    private weak var app: AppModel?
    private var unreadCount = 0
    private var waitingCount = 0
    private var keepsAwake = false
    private var strip = MenuBarUsageStrip()
    private let model = UsageMenuModel.shared
    private let panel = MenuBarPanelPresenter()

    private override init() {}

    func setEnabled(_ isEnabled: Bool, app: AppModel) {
        self.app = app
        model.refresh = { [weak app] in
            guard let app else { return }
            Task { await app.refreshQuotas(after: 0) }
        }

        guard isEnabled else {
            panel.close()
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        guard item == nil else { return }

        let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        created.button?.imagePosition = .imageLeading
        created.button?.target = self
        created.button?.action = #selector(togglePanel)
        _ = created.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        item = created
        observeUsage()
        refreshButton()
        claimPlaceInMenuBar(created)
    }

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppMenuBar", withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            let fallback = NSImage(
                systemSymbolName: "point.3.connected.trianglepath.dotted",
                accessibilityDescription: "Unified Dev"
            )
            fallback?.isTemplate = true
            return fallback
        }
        image.isTemplate = true
        image.accessibilityDescription = "Unified Dev"
        return image
    }()

    private func claimPlaceInMenuBar(_ item: NSStatusItem, attemptsLeft: Int = 3) {
        guard attemptsLeft > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard self.item === item, Self.isParked(item) else { return }
            item.isVisible = false
            item.isVisible = true
            claimPlaceInMenuBar(item, attemptsLeft: attemptsLeft - 1)
        }
    }

    private static func isParked(_ item: NSStatusItem) -> Bool {
        guard let window = item.button?.window else { return false }
        guard let screen = window.screen ?? NSScreen.main else { return false }
        return window.frame.maxX >= screen.frame.maxX
    }

    func setUnreadCount(_ count: Int) {
        guard count != unreadCount else { return }
        unreadCount = count
        refreshButton()
    }

    func setWaitingCount(_ count: Int) {
        guard count != waitingCount else { return }
        waitingCount = count
        refreshButton()
    }

    func setKeepsAwake(_ isOn: Bool) {
        guard isOn != keepsAwake else { return }
        keepsAwake = isOn
        refreshButton()
    }

    private func observeUsage() {
        guard let app, item != nil else { return }
        let metrics = withObservationTracking {
            _ = model.layout
            _ = model.options
            _ = model.iconStyle
            _ = model.showsUsage
            _ = model.showsWaitingCount
            _ = model.showsUnreadCount
            return UsageCatalogue.metrics(quotas: app.quotas, accounts: app.accounts)
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeUsage() }
        }
        model.adopt(metrics)
        strip = model.showsUsage
            ? MenuBarUsageStrip.make(layout: model.layout, metrics: metrics, options: model.options)
            : MenuBarUsageStrip()
        refreshButton()
    }

    private func refreshButton() {
        guard let button = item?.button else { return }
        if !strip.isEmpty, let image = MenuBarStripImage.image(for: strip, style: model.iconStyle) {
            button.image = image
        } else {
            button.image = Self.mark
        }

        let segments = MenuBarSummary.segments(
            waiting: waitingCount,
            unread: unreadCount,
            showsWaiting: model.showsWaitingCount,
            showsUnread: model.showsUnreadCount
        )
        let showsCup = keepsAwake && model.showsCup
        button.attributedTitle = Self.title(for: segments, keepsAwake: showsCup, font: button.font)

        var spoken = [MenuBarSummary.tooltip(waiting: waitingCount, unread: unreadCount)]
        if showsCup { spoken.insert(KeepAwake.onHeadline, at: 0) }
        if !strip.isEmpty { spoken.insert(strip.spoken, at: 0) }
        button.toolTip = spoken.joined(separator: "\n")
        button.setAccessibilityLabel("Unified Dev. " + spoken.joined(separator: ". "))
    }

    private static let leadingGap: CGFloat = 4
    private static let betweenGap: CGFloat = 7

    private static func title(
        for segments: [MenuBarSummary.Segment],
        keepsAwake: Bool,
        font: NSFont?
    ) -> NSAttributedString {
        let title = NSMutableAttributedString()
        let font = font ?? NSFont.menuBarFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        var isFirst = true
        func gap() {
            title.append(NSAttributedString(
                string: " ",
                attributes: [.font: font, .kern: isFirst ? leadingGap : betweenGap]
            ))
            isFirst = false
        }

        if keepsAwake, let cup = glyph(named: KeepAwake.menuBarSymbol, label: KeepAwake.onHeadline, font: font) {
            gap()
            title.append(cup)
        }
        for segment in segments {
            gap()
            if let glyph = glyph(named: segment.symbolName, label: segment.label, font: font) {
                title.append(glyph)
                title.append(NSAttributedString(string: " ", attributes: attributes))
            }
            title.append(NSAttributedString(string: String(segment.count), attributes: attributes))
        }
        return title
    }

    private static func glyph(named name: String, label: String, font: NSFont) -> NSAttributedString? {
        let configuration = NSImage.SymbolConfiguration(pointSize: font.pointSize * 0.72, weight: .semibold)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(configuration) else { return nil }
        image.isTemplate = true

        let attachment = NSTextAttachment()
        attachment.image = image
        let size = image.size
        attachment.bounds = CGRect(x: 0, y: font.descender * 0.5, width: size.width, height: size.height)
        return NSAttributedString(attachment: attachment)
    }

    @objc private func togglePanel() {
        guard let app, let button = item?.button else { return }
        panel.toggle(app: app, model: model, below: button)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let app {
            Task { await app.refreshQuotas(after: QuotaPollSchedule.onDemandFloor) }
        }

        for item in keepAwakeItems() { menu.addItem(item) }

        if let limits = limitsItem() {
            menu.addItem(.separator())
            menu.addItem(limits)
        }

        menu.addItem(.separator())
        addWorkspaces(to: menu)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Menubar Settings\u{2026}", keyEquivalent: ",") {
            SettingsTabRequest.post(.menuBar)
            Self.openAppSettings()
        })
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Unified Dev",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    private func keepAwakeItems() -> [NSMenuItem] {
        let keepAwake = KeepAwakeModel.shared
        let session = keepAwake.session
        let isRunning = keepAwake.isActive
        let defaults = UserDefaults.standard
        let now = Date()

        var items: [NSMenuItem] = []
        if let state = KeepAwake.menuState(
            session: session,
            whileAgentsRun: defaults.bool(forKey: SleepPrevention.settingKey),
            runningCount: app?.runningAgentCount ?? 0,
            at: now
        ) {
            items.append(disabled(state))
        }

        if isRunning {
            if session?.until != nil {
                var lengths: [NSMenuItem] = KeepAwake.extensionMinuteChoices.map { count in
                    ClosureMenuItem(KeepAwake.label(minutes: count)) {
                        keepAwake.extend(by: TimeInterval(count * 60))
                    }
                }
                lengths.append(.separator())
                lengths += KeepAwake.extensionHourChoices.map { count in
                    ClosureMenuItem(KeepAwake.label(hours: count)) {
                        keepAwake.extend(by: TimeInterval(count * 3600))
                    }
                }
                items.append(Self.submenu("Extend", lengths))
            }
            items.append(ClosureMenuItem("End Keep Awake") { keepAwake.stop() })
        } else {
            let durations: [NSMenuItem] = [
                Self.submenu("Minutes", KeepAwake.minuteChoices.map { count in
                    ClosureMenuItem(KeepAwake.label(minutes: count)) { keepAwake.start(for: TimeInterval(count * 60)) }
                }),
                Self.submenu("Hours", KeepAwake.hourChoices.map { count in
                    ClosureMenuItem(KeepAwake.label(hours: count)) { keepAwake.start(for: TimeInterval(count * 3600)) }
                }),
                .separator(),
                ClosureMenuItem("Indefinitely") { keepAwake.start(for: nil) },
            ]
            items.append(Self.submenu("Keep Awake For", durations))
        }

        items.append(Self.submenu("Keep Awake Settings", [
            agentsItem(defaults: defaults),
            lidItem(keepAwake: keepAwake),
        ]))
        return items
    }

    private func agentsItem(defaults: UserDefaults) -> NSMenuItem {
        let item = ClosureMenuItem(SleepPrevention.menuItemTitle) {
            defaults.set(!defaults.bool(forKey: SleepPrevention.settingKey), forKey: SleepPrevention.settingKey)
        }
        item.state = defaults.bool(forKey: SleepPrevention.settingKey) ? .on : .off
        item.toolTip = SleepPrevention.caveat
        return item
    }

    private func lidItem(keepAwake: KeepAwakeModel) -> NSMenuItem {
        let isApproved = SleepSwitch.shared.standing == .ready
        let title = "Keep Awake With the Lid Closed"
        let item = ClosureMenuItem(isApproved ? title : title + "\u{2026}") {
            keepAwake.keepsLidClosed.toggle()
            if keepAwake.keepsLidClosed, SleepSwitch.shared.standing == .needsApproval {
                SleepSwitch.shared.openApprovalSettings()
            }
        }
        item.state = keepAwake.keepsLidClosed && isApproved ? .on : .off
        item.toolTip = isApproved
            ? "A closing lid sleeps the Mac whatever an app asks for. This holds it open for the "
                + "length of a session."
            : "Needs Unified Dev's helper, which macOS asks you to allow once in System Settings."
        return item
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu()
        for item in items { menu.addItem(item) }
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    private func limitsItem() -> NSMenuItem? {
        guard model.showsUsage, let app else { return nil }
        let metrics = model.metrics(quotas: app.quotas, accounts: app.accounts)
        let sections = model.layout.sections(for: metrics)
        guard !sections.isEmpty else { return nil }

        let host = NSHostingView(rootView: UsageMenuBlock(
            model: model,
            metrics: metrics,
            accounts: app.accounts,
            observedAt: Self.oldestReadings(app.quotas),
            now: Date()
        ))
        host.frame = CGRect(origin: .zero, size: host.fittingSize)

        let item = NSMenuItem()
        item.view = host
        item.isEnabled = false
        item.setAccessibilityLabel(MenuBarSummary.limitSentence(for: QuotaBoard.make(from: app.quotas)))
        return item
    }

    static func oldestReadings(_ quotas: [AgentQuota]) -> [AgentKind: Date] {
        Dictionary(grouping: quotas, by: \.provider).compactMapValues { $0.map(\.observedAt).min() }
    }

    private func addWorkspaces(to menu: NSMenu) {
        let sections = MenuBarSummary.sections(
            in: app?.workspaces ?? [],
            isRunning: { app?.isRunning($0) ?? false },
            isAwaitingPermission: { app?.isAwaitingPermission($0) ?? false }
        )
        guard !sections.isEmpty else {
            menu.addItem(disabled(MenuBarSummary.emptyTitle))
            return
        }
        for section in sections {
            menu.addItem(disabled(section.heading))
            for workspace in section.workspaces {
                let item = NSMenuItem(title: workspace.name, action: #selector(select(_:)), keyEquivalent: "")
                item.target = self
                item.represent(workspace.id)
                item.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.label)
                menu.addItem(item)
            }
        }
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func select(_ sender: NSMenuItem) {
        guard let id = sender.represented(WorkspaceID.self) else { return }
        MainWindow.raise()
        OpenWorkspaceNotification.post(id)
    }

    static func openAppSettings() {
        SettingsWindow.open()
    }
}

@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, keyEquivalent: String = "", handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func fire() {
        handler()
    }
}
