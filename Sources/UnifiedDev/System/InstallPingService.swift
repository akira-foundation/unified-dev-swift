import AppKit
import Foundation
import SystemConfiguration
import Core

@MainActor
final class InstallPingService {
    static let shared = InstallPingService()

    private var loop: Task<Void, Never>?

    private weak var app: AppModel?

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    private init() {}

    func start(app: AppModel) {
        guard loop == nil else { return }
        self.app = app

        SystemDefaults.registerOnce()

        InstallPing.firstSeenAt()

        let environment = ProcessInfo.processInfo.environment
        guard let endpoint = InstallPing.endpoint(
            buildChannel: Bundle.main.object(forInfoDictionaryKey: SoftwareUpdate.buildChannelKey) as? String,
            masterCommit: Bundle.main.object(forInfoDictionaryKey: SoftwareUpdate.masterCommitKey) as? String,
            environment: environment
        ) else {
            Log.ping.info("No ping: this build has no endpoint to send to.")
            return
        }

        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(InstallPing.launchDelay))

            while !Task.isCancelled {
                let outcome = await self?.sendIfDue(to: endpoint)
                let delay = outcome.map(InstallPing.delay(after:)) ?? InstallPing.recheckInterval
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    @discardableResult
    private func sendIfDue(to endpoint: URL) async -> InstallPing.Outcome? {
        let defaults = UserDefaults.standard

        guard InstallPing.isEnabled(in: defaults) else { return nil }
        guard InstallPing.isDue(
            firstSeenAt: InstallPing.storedFirstSeenAt(in: defaults),
            lastSentAt: InstallPing.lastSentAt(in: defaults),
            now: Date()
        ) else { return nil }

        let payload = await currentPayload(token: InstallPing.installToken(in: defaults))
        guard let request = try? InstallPing.request(to: endpoint, payload: payload) else { return nil }

        let outcome = await send(request)

        if InstallPing.closesTheDay(outcome) {
            InstallPing.recordSend(at: Date(), in: defaults)
        }

        return outcome
    }

    private func currentPayload(token: String) async -> InstallPing.Payload {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let overrides = await executablePathOverrides()

        let installed = await Task.detached(priority: .background) {
            AgentCatalog.installedKinds(overrides: overrides)
        }.value

        let screen = NSScreen.main ?? NSScreen.screens.first

        return InstallPing.Payload(
            token: token,
            appVersion: version ?? InstallPing.unknownVersion,
            macOSVersion: InstallPing.macOSVersion(
                major: system.majorVersion,
                minor: system.minorVersion,
                patch: system.patchVersion
            ),
            agent: InstallPing.agentName(installed: installed),
            theme: InstallPing.Theme(),
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            computerName: SCDynamicStoreCopyComputerName(nil, nil) as String?,
            architecture: FeedbackEnvironment.architecture(),
            translated: FeedbackEnvironment.isTranslated(),
            screenWidth: screen.map { Double($0.frame.width) },
            screenHeight: screen.map { Double($0.frame.height) },
            displayScale: screen.map { Double($0.backingScaleFactor) },
            displayCount: NSScreen.screens.count,
            memoryBucket: InstallPing.MemoryBucket(bytes: ProcessInfo.processInfo.physicalMemory)
        )
    }

    private func executablePathOverrides() async -> [AgentKind: String] {
        await AgentCatalog.executablePathOverrides(in: app?.store)
    }

    private func send(_ request: URLRequest) async -> InstallPing.Outcome {
        do {
            let (_, response) = try await Self.session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }

            let outcome = InstallPing.outcome(
                statusCode: http.statusCode,
                retryAfter: http.value(forHTTPHeaderField: "Retry-After")
            )
            if outcome != .accepted {
                Log.ping.debug("Ping answered \(http.statusCode, privacy: .public)")
            }
            return outcome
        } catch {
            Log.ping.debug("Ping not sent: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }
}
