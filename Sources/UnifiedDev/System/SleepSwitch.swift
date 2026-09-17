import AppKit
import ServiceManagement
import Core

@MainActor
@Observable
final class SleepSwitch {
    static let shared = SleepSwitch()

    enum Standing: Equatable {
        case ready
        case needsApproval
        case unavailable(String)
    }

    private(set) var standing: Standing = .needsApproval

    @ObservationIgnored private let service = SMAppService.daemon(plistName: "io.akira.unifieddev.sleep.plist")
    @ObservationIgnored private var connection: NSXPCConnection?

    private init() {
        refreshStanding()
        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { SleepSwitch.shared.refresh() }
        }
    }

    func refresh() {
        refreshStanding()
    }

    @discardableResult
    func enable() -> Standing {
        switch service.status {
        case .enabled:
            standing = .ready
        case .requiresApproval:
            standing = .needsApproval
        case .notRegistered, .notFound:
            do {
                try service.register()
                refreshStanding()
            } catch {
                standing = .unavailable(TranscriptStanding.complaint(about: error))
            }
        @unknown default:
            standing = .needsApproval
        }
        return standing
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func setHoldingLidClosed(_ held: Bool) {
        refreshStanding()
        guard standing == .ready else { return }
        let proxy = proxy { [weak self] in
            MainActor.assumeIsolated { self?.connection = nil }
        }
        proxy?.setSleepDisabled(held, clientPID: ProcessInfo.processInfo.processIdentifier) { _ in }
    }

    func releaseOnQuit() {
        guard case .ready = standing else { return }
        proxy(onInvalidation: {})?.setSleepDisabled(false, clientPID: ProcessInfo.processInfo.processIdentifier) { _ in }
    }

    private func refreshStanding() {
        switch service.status {
        case .enabled: standing = .ready
        case .requiresApproval: standing = .needsApproval
        case .notRegistered, .notFound: if case .unavailable = standing {} else { standing = .needsApproval }
        @unknown default: standing = .needsApproval
        }
    }

    private func proxy(onInvalidation: @escaping @Sendable () -> Void) -> SleepControl? {
        if connection == nil {
            let created = NSXPCConnection(machServiceName: "io.akira.unifieddev.sleep", options: .privileged)
            created.remoteObjectInterface = NSXPCInterface(with: SleepControl.self)
            created.invalidationHandler = onInvalidation
            created.resume()
            connection = created
        }
        return connection?.remoteObjectProxyWithErrorHandler { _ in } as? SleepControl
    }
}

@objc protocol SleepControl {
    func setSleepDisabled(_ disabled: Bool, clientPID: Int32, withReply reply: @escaping (Bool) -> Void)
    func readSleepDisabled(withReply reply: @escaping (Bool) -> Void)
}
