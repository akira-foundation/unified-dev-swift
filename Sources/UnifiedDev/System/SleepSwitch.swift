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
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    private init() {
        refreshStanding()
        activationObserver = NotificationCenter.default.addObserver(
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
        send(held)
    }

    func releaseOnQuit() {
        guard case .ready = standing else { return }
        send(false)
    }

    private func send(_ disabled: Bool) {
        SleepDaemonConnection.setSleepDisabled(
            disabled, clientPID: ProcessInfo.processInfo.processIdentifier, over: liveConnection()
        ) { _ in }
    }

    private func refreshStanding() {
        switch service.status {
        case .enabled: standing = .ready
        case .requiresApproval: standing = .needsApproval
        case .notRegistered, .notFound: if case .unavailable = standing {} else { standing = .needsApproval }
        @unknown default: standing = .needsApproval
        }
    }

    private func liveConnection() -> NSXPCConnection {
        if let connection { return connection }
        let created = SleepDaemonConnection.open { [weak self] in
            Task { @MainActor in self?.connection = nil }
        }
        connection = created
        return created
    }
}
