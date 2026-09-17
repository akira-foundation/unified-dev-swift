import AppKit
import Foundation
import Core

@MainActor
final class AgentActivity {
    static let shared = AgentActivity()

    private var assertion: (any NSObjectProtocol)?

    private var heldOptions: ProcessInfo.ActivityOptions?

    private var runningCount = 0
    private var unreadCount = 0
    private var waitingCount = 0
    private var isBadgeEnabled = true
    private var preventsSleep = SleepPrevention.isOnByDefault
    private var keepAwakeSession: KeepAwakeSession?

    private init() {
        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AgentActivity.shared.releaseAssertion()
                SleepSwitch.shared.releaseOnQuit()
            }
        }
    }

    func setRunningCount(_ newCount: Int) {
        guard newCount != runningCount else { return }
        runningCount = newCount
        applyAssertion()
    }

    func setPreventsSleep(_ isOn: Bool) {
        guard isOn != preventsSleep else { return }
        preventsSleep = isOn
        applyAssertion()
    }

    func setKeepAwakeSession(_ session: KeepAwakeSession?) {
        guard session != keepAwakeSession else { return }
        keepAwakeSession = session
        applyAssertion()
    }

    func setUnreadCount(_ newCount: Int) {
        guard newCount != unreadCount else { return }
        unreadCount = newCount
        applyBadge()
    }

    func setWaitingCount(_ newCount: Int) {
        guard newCount != waitingCount else { return }
        waitingCount = newCount
        applyBadge()
    }

    func setBadgeEnabled(_ isEnabled: Bool) {
        guard isEnabled != isBadgeEnabled else { return }
        isBadgeEnabled = isEnabled
        applyBadge()
    }

    private func applyBadge() {
        NSApp?.dockTile.badgeLabel = DockBadge.label(
            unread: unreadCount, waiting: waitingCount, isEnabled: isBadgeEnabled
        )
    }

    private func applyAssertion() {
        defer { MenuBarStatusItem.shared.setKeepsAwake(heldOptions == .userInitiated) }
        let session = keepAwakeSession?.isActive(at: Date()) ?? false
        let wanted: ProcessInfo.ActivityOptions?
        if session {
            wanted = .userInitiated
        } else {
            wanted = runningCount > 0 ? wantedOptions : nil
        }
        guard wanted != heldOptions else { return }

        releaseAssertion()
        guard let wanted else { return }

        assertion = ProcessInfo.processInfo.beginActivity(
            options: wanted,
            reason: session ? "Keep Awake is on in Unified Dev" : "Coding agents are running"
        )
        heldOptions = wanted
    }

    private func releaseAssertion() {
        guard let held = assertion else { return }
        ProcessInfo.processInfo.endActivity(held)
        assertion = nil
        heldOptions = nil
    }

    private var wantedOptions: ProcessInfo.ActivityOptions {
        preventsSleep ? .userInitiated : .userInitiatedAllowingIdleSystemSleep
    }
}
