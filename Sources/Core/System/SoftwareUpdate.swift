import Foundation

public enum SoftwareUpdate {
    public static let repository = "akira-foundation/unified-dev-swift"

    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    public static let checksAutomaticallyKey = "updates.checksAutomatically"

    public static let lastCheckedKey = "updates.lastCheckedAt"

    public static let skippedVersionKey = "updates.skippedVersion"

    public static let checksAutomaticallyByDefault = true

    public static let checkInterval: TimeInterval = 86_400

    public static let launchDelay: TimeInterval = 30

    public static let recheckInterval: TimeInterval = 3_600

    public enum Availability: Equatable, Sendable {
        case available(currentVersion: ReleaseVersion)
        case localBuild
    }

    public static func availability(of identity: BuildIdentity) -> Availability {
        guard case .release(let version, _) = identity, let current = ReleaseVersion(version) else {
            return .localBuild
        }
        return .available(currentVersion: current)
    }

    public static func assetName(for version: ReleaseVersion) -> String {
        "unified_dev_\(version)_aarch64.zip"
    }

    public enum Offer: Equatable, Sendable {
        case install(GitHubRelease, GitHubRelease.Asset)
        case upToDate
        case skipped(GitHubRelease)
        case missingAsset(GitHubRelease)
    }

    public static func offer(
        for release: GitHubRelease,
        currentVersion: ReleaseVersion,
        skippedVersion: String?
    ) -> Offer {
        guard !release.isDraft, !release.isPrerelease, !release.version.isPrerelease,
              currentVersion < release.version else {
            return .upToDate
        }
        if skippedVersion == release.version.description {
            return .skipped(release)
        }
        guard let asset = release.asset(named: assetName(for: release.version)) else {
            return .missingAsset(release)
        }
        return .install(release, asset)
    }

    public static func isDue(lastCheckedAt: Date?, now: Date) -> Bool {
        guard let lastCheckedAt, lastCheckedAt <= now else { return true }
        return now.timeIntervalSince(lastCheckedAt) >= checkInterval
    }

    public static func recordsCheck(of offer: Offer, userInitiated: Bool) -> Bool {
        guard case .missingAsset = offer else { return true }
        return userInitiated
    }

    public static func mayCheckInBackground(runningCount: Int) -> Bool {
        runningCount == 0
    }

    public static let sectionTitle = "Updates"

    public static let settingTitle = "Check for updates automatically"

    public static let settingDetail =
        "Once a day from GitHub Releases, and never while an agent is running. Nothing is installed until you say so."

    public static let localBuildExplanation =
        "This copy was built from source, so it updates when you build it again."

    public static let upToDateTitle = "Unified Dev is up to date"

    public static func upToDateDetail(current: ReleaseVersion) -> String {
        "Version \(current) is the newest release."
    }

    public static func availableTitle(_ release: GitHubRelease) -> String {
        "Unified Dev \(release.version) is available"
    }

    public static func availableDetail(_ release: GitHubRelease, current: ReleaseVersion) -> String {
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let intro = "You have version \(current)."
        guard !notes.isEmpty else { return intro }
        let limit = 1_200
        let shown = notes.count > limit ? String(notes.prefix(limit)) + "\u{2026}" : notes
        return intro + "\n\n" + shown
    }

    public static let installButtonTitle = "Install and Restart"

    public static let laterButtonTitle = "Later"

    public static let skipButtonTitle = "Skip This Version"

    public static let releasePageButtonTitle = "Open Release Page"

    public static func missingAssetDetail(_ release: GitHubRelease) -> String {
        "Version \(release.version) has no download for this Mac yet. The release page has everything that was published."
    }

    public static let failureTitle = "The update could not be installed"

    public static let checkFailureTitle = "Unified Dev could not check for updates"

    public static func interruptionTitle(runningCount: Int) -> String {
        runningCount == 1
            ? "An agent is still running"
            : "\(runningCount) agents are still running"
    }

    public static func interruptionDetail(runningCount: Int, workspaceNames: [String]) -> String {
        var detail = runningCount == 1
            ? "Installing this update restarts Unified Dev. The turn it is in the middle of will not be finished, and it cannot be resumed."
            : "Installing this update restarts Unified Dev. The turns they are in the middle of will not be finished, and they cannot be resumed."

        let shown = workspaceNames.prefix(5)
        if !shown.isEmpty {
            detail += "\n\n" + shown.map { "\u{2022} \($0)" }.joined(separator: "\n")
            if workspaceNames.count > shown.count {
                detail += "\n\u{2022} and \(workspaceNames.count - shown.count) more"
            }
        }

        return detail
    }
}
