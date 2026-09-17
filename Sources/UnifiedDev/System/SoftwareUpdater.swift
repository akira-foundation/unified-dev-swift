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

    @ObservationIgnored private var pendingReplacement: UpdateInstaller.Replacement?

    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private static let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/Unified Dev/update.log")

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

    func launchPendingReplacement() {
        guard let replacement = pendingReplacement else { return }
        pendingReplacement = nil
        do {
            try UpdateInstaller.launchReplacement(
                processID: ProcessInfo.processInfo.processIdentifier, replacement: replacement
            )
            Log.updates.info("Replacement handed off; log at \(replacement.log.path, privacy: .public)")
        } catch {
            Log.updates.error("Replacement did not start: \(String(describing: error), privacy: .public)")
        }
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

        guard let release else {
            UserDefaults.standard.set(Date(), forKey: SoftwareUpdate.lastCheckedKey)
            if userInitiated { showAlert(SoftwareUpdate.upToDateTitle, SoftwareUpdate.upToDateDetail(current: current)) }
            return
        }

        let skipped = userInitiated ? nil : UserDefaults.standard.string(forKey: SoftwareUpdate.skippedVersionKey)
        let offer = SoftwareUpdate.offer(for: release, currentVersion: current, skippedVersion: skipped)
        if SoftwareUpdate.recordsCheck(of: offer, userInitiated: userInitiated) {
            UserDefaults.standard.set(Date(), forKey: SoftwareUpdate.lastCheckedKey)
        }

        switch offer {
        case .upToDate:
            if userInitiated { showAlert(SoftwareUpdate.upToDateTitle, SoftwareUpdate.upToDateDetail(current: current)) }
        case .skipped:
            return
        case .missingAsset(let release):
            if userInitiated {
                showFailure(SoftwareUpdate.missingAssetDetail(release), release: release, title: SoftwareUpdate.availableTitle(release))
            }
        case .install(let release, let asset):
            presentWhenActive { $0.offer(release, asset: asset, current: current) }
        }
    }

    private func presentWhenActive(_ present: @escaping @MainActor (SoftwareUpdater) -> Void) {
        guard !NSApp.isActive else {
            present(self)
            return
        }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let observer = self.activationObserver { NotificationCenter.default.removeObserver(observer) }
                self.activationObserver = nil
                present(self)
            }
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
                return .failure(URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "GitHub answered \(status)."]))
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
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"

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
        if let trouble = UpdateInstaller.replaceability(of: target) {
            showFailure(trouble.description, release: release)
            return
        }
        guard let requirement = Self.runningDesignatedRequirement() else {
            showFailure("This copy carries no signature to check the download against.", release: release)
            return
        }

        phase = .installing
        do {
            let staged = try await UpdateInstaller.stage(
                asset: asset,
                version: release.version,
                requirement: requirement,
                workDirectory: FileManager.default.temporaryDirectory.appending(path: "unifieddev-update"),
                session: Self.session
            )
            try await UpdateInstaller.assessNotarisation(of: staged)

            let running = app?.runningAgentCount ?? 0
            guard running == 0 || installNowWasChosen(running: running, workspaceNames: app?.runningAgentWorkspaceNames ?? []) else {
                phase = .idle
                return
            }

            pendingReplacement = UpdateInstaller.Replacement(
                staged: staged, target: target, requirement: requirement, log: Self.logFile
            )
            appDelegate?.isInstallingUpdate = true
            Log.updates.info("Installing \(release.version.description, privacy: .public) and restarting")
            NSApp.terminate(nil)
            recoverIfTerminationWasCancelled()
        } catch {
            phase = .idle
            Log.updates.error("Install failed: \(String(describing: error), privacy: .public)")
            showFailure(String(describing: error), release: release)
        }
    }

    private func recoverIfTerminationWasCancelled() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, self.phase == .installing else { return }
            Log.updates.info("Restart did not happen; the update was put back")
            self.pendingReplacement = nil
            self.appDelegate?.isInstallingUpdate = false
            self.phase = .idle
        }
    }

    private static func runningDesignatedRequirement() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess, let requirement else {
            return nil
        }
        var text: CFString?
        guard SecRequirementCopyString(requirement, [], &text) == errSecSuccess, let text else { return nil }
        return text as String
    }
}
