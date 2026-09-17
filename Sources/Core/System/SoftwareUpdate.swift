import Foundation

public enum SoftwareUpdate {
    public static let feedURLKey = "SUFeedURL"
    public static let publicKeyKey = "SUPublicEDKey"

    public static let buildChannelKey = "BuildChannel"

    public static let masterCommitKey = "MasterCommit"

    public static let placeholderPrefix = "__UD_"

    public static let releaseChannel = "release"

    public static let checkInterval: TimeInterval = 86_400

    public enum Availability: Equatable, Sendable {
        case configured(feedURL: String)

        case localBuild

        case notConfigured
    }

    public static func availability(
        feedURL: String?,
        publicKey: String?,
        buildChannel: String?,
        masterCommit: String?
    ) -> Availability {
        if masterCommit?.isEmpty == false { return .localBuild }
        guard buildChannel == releaseChannel else { return .localBuild }

        guard let feedURL = filled(feedURL), filled(publicKey) != nil else { return .notConfigured }

        return .configured(feedURL: feedURL)
    }

    public static func availability(in bundle: Bundle) -> Availability {
        availability(
            feedURL: bundle.object(forInfoDictionaryKey: feedURLKey) as? String,
            publicKey: bundle.object(forInfoDictionaryKey: publicKeyKey) as? String,
            buildChannel: bundle.object(forInfoDictionaryKey: buildChannelKey) as? String,
            masterCommit: bundle.object(forInfoDictionaryKey: masterCommitKey) as? String
        )
    }

    private static func filled(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(placeholderPrefix) else { return nil }
        return trimmed
    }

    public static func mayCheckInBackground(runningCount: Int) -> Bool {
        runningCount == 0
    }

    public static let backgroundCheckDeferred =
        "Unified Dev does not check for updates in the background while agents are running."

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

    public static let waitButtonTitle = "Install When They Finish"

    public static let installNowButtonTitle = "Install and Restart Now"

    public static let sectionTitle = "Updates"

    public static let settingTitle = "Check for updates automatically"

    public static let settingDetail =
        "Once a day, and never while an agent is running. Nothing is downloaded or installed until you say so."

    public static func unavailableExplanation(_ availability: Availability) -> String? {
        switch availability {
        case .configured: nil
        case .localBuild: "This copy was built from source, so it updates when you build it again."
        case .notConfigured: "This build has no update feed configured."
        }
    }
}
