import Foundation

public enum BuildIdentity: Equatable, Sendable {
    public static let buildChannelKey = "BuildChannel"

    public static let masterCommitKey = "MasterCommit"

    public static let releaseChannel = "release"

    case release(version: String, build: String)

    case master(commit: String)

    case local

    public static func read(
        version: String?,
        build: String?,
        buildChannel: String?,
        masterCommit: String?
    ) -> BuildIdentity {
        if let commit = filled(masterCommit) { return .master(commit: commit) }
        guard buildChannel == releaseChannel, let version = filled(version) else {
            return .local
        }
        return .release(version: version, build: filled(build) ?? version)
    }

    public static func read(from bundle: Bundle) -> BuildIdentity {
        read(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            buildChannel: bundle.object(forInfoDictionaryKey: buildChannelKey)
                as? String,
            masterCommit: bundle.object(forInfoDictionaryKey: masterCommitKey)
                as? String
        )
    }

    public var line: String {
        switch self {
        case .release(let version, let build) where build == version:
            "Version \(version)"
        case .release(let version, let build):
            "Version \(version) · Build \(build)"
        case .master(let commit):
            "Development build · \(commit.prefix(7))"
        case .local:
            "Development build"
        }
    }

    public func line(
        built: Date?,
        now: Date = Date(),
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        guard !isRelease, let built else { return line }
        return "\(line) · \(BuildTimestamp.line(built, now: now, locale: locale, timeZone: timeZone))"
    }

    public var value: String {
        switch self {
        case .release(let version, let build) where build == version: version
        case .release(let version, let build): "\(version) (\(build))"
        case .master, .local: line
        }
    }

    public var isRelease: Bool {
        if case .release = self { return true }
        return false
    }

    private static func filled(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
