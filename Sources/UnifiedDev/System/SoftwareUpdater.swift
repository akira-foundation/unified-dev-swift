import AppKit
import Observation
import Sparkle
import Core

@MainActor
@Observable
final class SoftwareUpdater: NSObject, SPUUpdaterDelegate {
    static let shared = SoftwareUpdater()

    private(set) var availability: SoftwareUpdate.Availability = .localBuild

    private(set) var canCheckForUpdates = false

    private(set) var checksAutomatically = false

    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    @ObservationIgnored private weak var app: AppModel?

    @ObservationIgnored private weak var appDelegate: AppDelegate?

    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var automaticChecksObservation: NSKeyValueObservation?

    @ObservationIgnored private var postponedInstall: (() -> Void)?

    private override init() {}

    func start(app: AppModel, appDelegate: AppDelegate) {
        self.app = app
        self.appDelegate = appDelegate
        guard controller == nil else { return }

        availability = SoftwareUpdate.availability(in: .main)
        guard case .configured(let feedURL) = availability else {
            Log.updates.info("Updates are off for this build: \(String(describing: self.availability), privacy: .public)")
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.controller = controller

        let updater = controller.updater
        updater.updateCheckInterval = SoftwareUpdate.checkInterval
        updater.automaticallyDownloadsUpdates = false
        updater.sendsSystemProfile = false

        controller.startUpdater()

        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
            hopToMain { self?.refreshCanCheck() }
        }
        automaticChecksObservation = updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] _, _ in
            hopToMain { self?.refreshChecksAutomatically() }
        }

        Log.updates.info("Updates on, feed \(feedURL, privacy: .public)")
    }

    func checkForUpdates() {
        controller?.updater.checkForUpdates()
    }

    func setChecksAutomatically(_ isEnabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = isEnabled
        refreshChecksAutomatically()
    }

    private func refreshCanCheck() {
        let value = controller?.updater.canCheckForUpdates ?? false
        if canCheckForUpdates != value { canCheckForUpdates = value }
    }

    private func refreshChecksAutomatically() {
        let value = controller?.updater.automaticallyChecksForUpdates ?? false
        if checksAutomatically != value { checksAutomatically = value }
    }

    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
        false
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard updateCheck == .updatesInBackground else { return }

        let running = app?.runningAgentCount ?? 0
        guard !SoftwareUpdate.mayCheckInBackground(runningCount: running) else { return }

        Log.updates.info("Background check deferred: \(running, privacy: .public) agents running")
        throw NSError(
            domain: "io.akira.unifieddev.updates",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: SoftwareUpdate.backgroundCheckDeferred]
        )
    }

    func updater(
        _ updater: SPUUpdater,
        shouldPostponeRelaunchForUpdate item: SUAppcastItem,
        untilInvokingBlock installHandler: @escaping () -> Void
    ) -> Bool {
        let running = app?.runningAgentCount ?? 0
        guard running > 0 else {
            allowTerminationWithoutAsking()
            return false
        }

        if installNowWasChosen(running: running) {
            allowTerminationWithoutAsking()
            return false
        }

        Log.updates.info("Install postponed until \(running, privacy: .public) agents finish")
        postponedInstall = installHandler
        controller?.userDriver.dismissUpdateInstallation()
        waitForAgentsThenInstall()
        return true
    }

    private func installNowWasChosen(running: Int) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = SoftwareUpdate.interruptionTitle(runningCount: running)
        alert.informativeText = SoftwareUpdate.interruptionDetail(
            runningCount: running,
            workspaceNames: app?.runningAgentWorkspaceNames ?? []
        )

        alert.addButton(withTitle: SoftwareUpdate.installNowButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.waitButtonTitle)
        alert.buttons.last?.keyEquivalent = "\r"
        alert.buttons.first?.keyEquivalent = ""

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func waitForAgentsThenInstall() {
        Task { @MainActor in
            while let app, app.runningAgentCount > 0 {
                try? await Task.sleep(for: .seconds(5))
            }
            guard let install = postponedInstall else { return }
            postponedInstall = nil
            Log.updates.info("Agents finished, installing the postponed update")
            allowTerminationWithoutAsking()
            install()
        }
    }

    private func allowTerminationWithoutAsking() {
        appDelegate?.isInstallingUpdate = true
    }
}
