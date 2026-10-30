import Foundation

public enum SoftwareUpdate {
    public static let repository = AppRepository.slug

    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    public static let checksAutomaticallyKey = "updates.checksAutomatically"

    public static let lastCheckedKey = "updates.lastCheckedAt"

    public static let skippedVersionKey = "updates.skippedVersion"

    public static let checksAutomaticallyByDefault = true

    public static let checkInterval: TimeInterval = 86_400

    public static let launchDelay: TimeInterval = 30

    public static let seededLaunchDelay: TimeInterval = 3

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

        public var release: GitHubRelease? {
            switch self {
            case .install(let release, _), .skipped(let release), .missingAsset(let release): release
            case .upToDate: nil
            }
        }
    }

    public static func installable(_ offer: Offer) -> (release: GitHubRelease, asset: GitHubRelease.Asset)? {
        switch offer {
        case .install(let release, let asset):
            (release, asset)
        case .skipped(let release):
            asset(of: release).map { (release, $0) }
        case .upToDate, .missingAsset:
            nil
        }
    }

    public static func asset(of release: GitHubRelease) -> GitHubRelease.Asset? {
        release.asset(named: assetName(for: release.version))
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
        guard let asset = asset(of: release) else {
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

    public static let installButtonTitle = "Install and Restart"

    public static let laterButtonTitle = "Later"

    public static let skipButtonTitle = "Skip This Version"

    public static let releasePageButtonTitle = "Open Release Page"

    public static let closeButtonTitle = "Close"

    public static let notesLabel = "Release notes"

    public struct Prompt: Equatable, Sendable {
        public enum Button: Equatable, Sendable {
            case install
            case later
            case skip
            case releasePage
            case close

            public var title: String {
                switch self {
                case .install: SoftwareUpdate.installButtonTitle
                case .later: SoftwareUpdate.laterButtonTitle
                case .skip: SoftwareUpdate.skipButtonTitle
                case .releasePage: SoftwareUpdate.releasePageButtonTitle
                case .close: SoftwareUpdate.closeButtonTitle
                }
            }
        }

        public let title: String
        public let detail: String
        public let notes: String
        public let buttons: [Button]
        public let defaultButton: Button

        public init(title: String, detail: String, notes: String, buttons: [Button], defaultButton: Button) {
            self.title = title
            self.detail = detail
            self.notes = notes
            self.buttons = buttons
            self.defaultButton = defaultButton
        }
    }

    public static func prompt(for offer: Offer, currentVersion: ReleaseVersion) -> Prompt {
        guard let release = offer.release else {
            return Prompt(
                title: upToDateTitle,
                detail: upToDateDetail(current: currentVersion),
                notes: "",
                buttons: [.close],
                defaultButton: .close
            )
        }
        let written = notes(of: release)
        return Prompt(
            title: availableTitle(release),
            detail: detail(for: offer, current: currentVersion, hasNotes: !written.isEmpty),
            notes: written,
            buttons: buttons(for: offer),
            defaultButton: .later
        )
    }

    private static func detail(for offer: Offer, current: ReleaseVersion, hasNotes: Bool) -> String {
        switch offer {
        case .skipped(let release): skippedDetail(release, current: current)
        case .missingAsset(let release): missingAssetDetail(release)
        case .install, .upToDate: offerDetail(current: current, hasNotes: hasNotes)
        }
    }

    private static func buttons(for offer: Offer) -> [Prompt.Button] {
        switch offer {
        case .install: [.install, .later, .skip]
        case .skipped: installable(offer) == nil ? [.releasePage, .later] : [.install, .later]
        case .missingAsset: [.releasePage, .later, .skip]
        case .upToDate: [.close]
        }
    }

    public static let notesLimit = 8_000

    public static func notes(of release: GitHubRelease) -> String {
        let body = release.notes
        guard body.count > notesLimit else { return MarkdownPlainText.render(body) }
        let kept = MarkdownPlainText.render(String(body.prefix(notesLimit)))
        return kept + "\n\n" + notesCutNotice
    }

    public static let notesCutNotice =
        "The rest of these notes was cut off here. The release page has all of it."

    public static func offerDetail(current: ReleaseVersion, hasNotes: Bool) -> String {
        hasNotes
            ? "You have version \(current). Nothing is downloaded or installed until you ask for it."
            : "You have version \(current). This release published no notes, and the release page has everything that went with it."
    }

    public static func skippedDetail(_ release: GitHubRelease, current: ReleaseVersion) -> String {
        "You have version \(current), and you skipped \(release.version). "
            + "Nothing will offer it again on its own, and you asked, so here it is."
    }

    public static func missingAssetDetail(_ release: GitHubRelease) -> String {
        "Version \(release.version) has no download for this Mac yet. The release page has everything that was published."
    }

    public static let failureTitle = "The update could not be installed"

    public static let seededTitle = "This update is here to be looked at"

    public static let seededDetail =
        "A preview offers a release that was never published, so there is nothing to download and nothing to "
        + "install. Everything up to this button is what a real update does."

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
