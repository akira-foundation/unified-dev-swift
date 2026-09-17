import AppKit
import Observation
import Security
import Core

@MainActor
@Observable
final class SoftwareUpdater {
    static let shared = SoftwareUpdater()

    enum Phase: Equatable {
        case idle
        case checking
        case installing
    }

    private(set) var availability: SoftwareUpdate.Availability = .localBuild

    private(set) var phase: Phase = .idle

    var canCheckForUpdates: Bool {
        availability != .localBuild && phase == .idle
    }

    @ObservationIgnored private weak var app: AppModel?

    @ObservationIgnored private weak var appDelegate: AppDelegate?

    @ObservationIgnored private var loop: Task<Void, Never>?

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private init() {}

    func start(app: AppModel, appDelegate: AppDelegate) {
        self.app = app
        self.appDelegate = appDelegate
        guard loop == nil else { return }

        availability = SoftwareUpdate.availability(of: BuildIdentity.read(from: .main))
        guard case .available(let current) = availability else {
            Log.updates.info("Updates are off: this copy was built from source")
            return
        }
        Log.updates.info("Updates on for \(current.description, privacy: .public)")

        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(SoftwareUpdate.launchDelay))
            while !Task.isCancelled {
                await self?.checkInBackgroundIfDue()
                try? await Task.sleep(for: .seconds(SoftwareUpdate.recheckInterval))
            }
        }
    }

    func checkForUpdates() {
        Task { await check(userInitiated: true) }
    }

    private func checkInBackgroundIfDue() async {
        let defaults = UserDefaults.standard
        let automatic = defaults.object(forKey: SoftwareUpdate.checksAutomaticallyKey) as? Bool
            ?? SoftwareUpdate.checksAutomaticallyByDefault
        guard automatic else { return }
        guard SoftwareUpdate.isDue(
            lastCheckedAt: defaults.object(forKey: SoftwareUpdate.lastCheckedKey) as? Date,
            now: Date()
        ) else { return }
        guard SoftwareUpdate.mayCheckInBackground(runningCount: app?.runningAgentCount ?? 0) else {
            Log.updates.info("Background check deferred while agents run")
            return
        }
        await check(userInitiated: false)
    }

    private func check(userInitiated: Bool) async {
        guard case .available(let current) = availability, phase == .idle else { return }

        phase = .checking
        let result = await fetchLatestRelease()
        phase = .idle

        let release: GitHubRelease?
        switch result {
        case .success(let fetched):
            release = fetched
        case .failure(let trouble):
            Log.updates.error("Check failed: \(trouble.localizedDescription, privacy: .public)")
            if userInitiated { showAlert(SoftwareUpdate.checkFailureTitle, trouble.localizedDescription) }
            return
        }

        UserDefaults.standard.set(Date(), forKey: SoftwareUpdate.lastCheckedKey)

        guard let release else {
            if userInitiated { showUpToDate(current) }
            return
        }

        let skipped = userInitiated ? nil : UserDefaults.standard.string(forKey: SoftwareUpdate.skippedVersionKey)
        switch SoftwareUpdate.offer(for: release, currentVersion: current, skippedVersion: skipped) {
        case .upToDate:
            if userInitiated { showUpToDate(current) }
        case .skipped:
            return
        case .missingAsset(let release):
            if userInitiated { showMissingAsset(release) }
        case .install(let release, let asset):
            offer(release, asset: asset, current: current)
        }
    }

    private func fetchLatestRelease() async -> Result<GitHubRelease?, Error> {
        var request = URLRequest(url: SoftwareUpdate.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("UnifiedDev", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await Self.session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 { return .success(nil) }
            guard status == 200 else {
                return .failure(URLError(.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "GitHub answered \(status).",
                ]))
            }
            return .success(try GitHubRelease.decode(data))
        } catch {
            return .failure(error)
        }
    }

    private func offer(_ release: GitHubRelease, asset: GitHubRelease.Asset, current: ReleaseVersion) {
        let alert = NSAlert()
        alert.messageText = SoftwareUpdate.availableTitle(release)
        alert.informativeText = SoftwareUpdate.availableDetail(release, current: current)
        alert.addButton(withTitle: SoftwareUpdate.installButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.laterButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.skipButtonTitle)

        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            UserDefaults.standard.removeObject(forKey: SoftwareUpdate.skippedVersionKey)
            Task { await install(release, asset: asset) }
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(release.version.description, forKey: SoftwareUpdate.skippedVersionKey)
        default:
            return
        }
    }

    private func install(_ release: GitHubRelease, asset: GitHubRelease.Asset) async {
        guard phase == .idle else { return }

        let target = Bundle.main.bundleURL
        guard UpdateInstaller.canReplace(bundleAt: target) else {
            showFailure(UpdateInstaller.Trouble.notWritable(path: target.path).description, release: release)
            return
        }
        guard let teamID = Self.runningTeamID() else {
            showFailure("This copy carries no Developer ID signature to check the download against.", release: release)
            return
        }

        let running = app?.runningAgentCount ?? 0
        guard running == 0 || installNowWasChosen(running: running) else { return }

        phase = .installing
        do {
            let staged = try await UpdateInstaller.stage(
                asset: asset,
                version: release.version,
                teamID: teamID,
                workDirectory: FileManager.default.temporaryDirectory.appending(path: "unifieddev-update"),
                session: Self.session
            )
            try UpdateInstaller.launchReplacement(
                processID: ProcessInfo.processInfo.processIdentifier,
                staged: staged,
                target: target
            )
            Log.updates.info("Installing \(release.version.description, privacy: .public) and restarting")
            appDelegate?.isInstallingUpdate = true
            NSApp.terminate(nil)
        } catch {
            phase = .idle
            Log.updates.error("Install failed: \(String(describing: error), privacy: .public)")
            showFailure(String(describing: error), release: release)
        }
    }

    private func installNowWasChosen(running: Int) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = SoftwareUpdate.interruptionTitle(runningCount: running)
        alert.informativeText = SoftwareUpdate.interruptionDetail(
            runningCount: running,
            workspaceNames: app?.runningAgentWorkspaceNames ?? []
        )
        alert.addButton(withTitle: SoftwareUpdate.installButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.laterButtonTitle)
        alert.buttons.last?.keyEquivalent = "\r"
        alert.buttons.first?.keyEquivalent = ""
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showUpToDate(_ current: ReleaseVersion) {
        showAlert(SoftwareUpdate.upToDateTitle, SoftwareUpdate.upToDateDetail(current: current))
    }

    private func showMissingAsset(_ release: GitHubRelease) {
        showFailure(SoftwareUpdate.missingAssetDetail(release), release: release, title: SoftwareUpdate.availableTitle(release))
    }

    private func showFailure(_ detail: String, release: GitHubRelease, title: String = SoftwareUpdate.failureTitle) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: SoftwareUpdate.releasePageButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.laterButtonTitle)
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.pageURL)
        }
    }

    private func showAlert(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        NSApp.activate()
        alert.runModal()
    }

    private static func runningTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &information) == errSecSuccess,
              let information = information as? [String: Any] else { return nil }
        return information[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
