import AppKit
import Foundation
import Core

@MainActor
enum FeedbackEnvironment {
    static let versionKey = "feedback.agentVersion"
    static let versionCheckedKey = "feedback.agentVersionCheckedAt"

    static let versionLifetime: TimeInterval = 24 * 60 * 60

    static let versionTimeout: Duration = .seconds(5)

    static func current(app: AppModel?) async -> Feedback.Environment {
        let defaults = UserDefaults.standard
        let bundle = Bundle.main

        let overrides = await executablePathOverrides(app: app)
        let permissionMode = await permissionMode(app: app)

        let installed = await Task.detached(priority: .userInitiated) {
            await AgentCatalog.installedKinds(overrides: overrides)
        }.value

        let running = AgentKind.allCases.first { $0.canRunWorkspaces && installed.contains($0) }
        let agentVersion = await agentVersion(of: running, overrides: overrides, defaults: defaults)

        let system = ProcessInfo.processInfo.operatingSystemVersion

        return Feedback.Environment(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            macOSVersion: InstallPing.macOSVersion(
                major: system.majorVersion, minor: system.minorVersion, patch: system.patchVersion
            ),
            architecture: architecture(),
            translated: isTranslated(),
            installSource: Feedback.InstallSource(
                buildChannel: bundle.object(forInfoDictionaryKey: BuildIdentity.buildChannelKey) as? String,
                masterCommit: bundle.object(forInfoDictionaryKey: BuildIdentity.masterCommitKey) as? String,
                isDirty: bundle.object(forInfoDictionaryKey: Feedback.InstallSource.dirtyKey) as? Bool
            ),
            agent: InstallPing.agentName(installed: installed),
            agentVersion: agentVersion,
            availableAgents: installed.map(InstallPing.wireName),
            permissionMode: Feedback.wireName(permissionMode),
            theme: InstallPing.Theme(in: defaults),
            displayScale: displayScale(),
            locale: locale()
        )
    }

    static func token() -> String {
        InstallPing.installToken()
    }

    static func architecture() -> Feedback.Architecture {
        Feedback.Architecture(isARM: sysctlFlag(armFlag), isTranslated: isTranslated())
    }

    static func isTranslated() -> Bool {
        sysctlFlag(translatedFlag)
    }

    static let armFlag = "hw.optional.arm64"
    static let translatedFlag = "sysctl.proc_translated"

    static func sysctlFlag(_ name: String) -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return false }
        return value == 1
    }

    static func displayScale() -> Double {
        Double(NSScreen.main?.backingScaleFactor ?? 1)
    }

    static func locale() -> String {
        let language = (Locale.current.language.languageCode?.identifier ?? "").lowercased()
        guard !language.isEmpty else { return "" }
        guard let region = Locale.current.region?.identifier, !region.isEmpty else { return language }
        return "\(language)-\(region)"
    }

    static func permissionMode(app: AppModel?) async -> PermissionMode {
        guard let store = app?.store else { return AppDefaults.fallbackPermissionMode }
        let defaults = await AppDefaults.load(from: store)
        return defaults.planMode ? .plan : defaults.permissionMode
    }

    static func executablePathOverrides(app: AppModel?) async -> [AgentKind: String] {
        await AgentCatalog.executablePathOverrides(in: app?.store)
    }

    static func agentVersion(
        of kind: AgentKind?,
        overrides: [AgentKind: String],
        defaults: UserDefaults
    ) async -> String {
        guard let kind else { return "" }

        if let remembered = rememberedVersion(in: defaults) { return remembered }

        let timeout = versionTimeout
        let name = overrides[kind].map { ($0 as NSString).expandingTildeInPath } ?? kind.executableName

        let found = await Task.detached(priority: .userInitiated) { () -> String in
            guard let path = Shell.which(name) else { return "" }
            guard let result = try? await Shell.run(path, ["--version"], timeout: timeout) else {
                return ""
            }
            let stdout = result.trimmed
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return AgentCatalog.parseVersion(stdout.isEmpty ? stderr : stdout) ?? ""
        }.value

        remember(found, in: defaults)
        return found
    }

    static func rememberedVersion(in defaults: UserDefaults) -> String? {
        guard let checked = defaults.object(forKey: versionCheckedKey) as? Date else { return nil }
        guard checked <= Date(), Date().timeIntervalSince(checked) < versionLifetime else { return nil }
        guard let version = defaults.string(forKey: versionKey), !version.isEmpty else { return nil }
        return version
    }

    static func remember(_ version: String, in defaults: UserDefaults) {
        defaults.set(version, forKey: versionKey)
        defaults.set(Date(), forKey: versionCheckedKey)
    }
}
