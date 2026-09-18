import Foundation

public struct PreviewIdentity: Sendable, Equatable {
    public static let bundlePrefix = Store.devBundleIdentifier + "."
    public static let rootOverride = "UD_PREVIEW_ROOT"
    public static let titlePrefixKey = "UDWindowTitlePrefix"
    public static let labelLimit = 40

    public let worktree: String
    public let slug: String
    public let issue: Int?
    public let label: String

    public init(worktree: String, branch: String?, label: String?) throws {
        let standardized = (worktree as NSString).standardizingPath
        let slug = BridgeRegistration.slugified((standardized as NSString).lastPathComponent)
        guard standardized.hasPrefix("/"), !slug.isEmpty else {
            throw PreviewIdentityError.noSlug(worktree)
        }
        self.worktree = standardized
        self.slug = slug
        self.issue = branch.flatMap(Self.issue(fromBranch:))
        self.label = [Self.cleanLabel(label), Self.cleanLabel(branch)].first { !$0.isEmpty } ?? slug
    }

    public var bundleIdentifier: String { Self.bundlePrefix + slug }

    public var appName: String { issue.map { "UD #\($0)" } ?? "UD \(slug)" }

    public var windowTitlePrefix: String { "[DEV \u{00B7} \(label)] " }

    public var urlScheme: String { "unifieddevdev-" + slug }

    public var servicesMenuItem: String { "New \(appName) Workspace" }

    public var root: String { worktree + "/.build/preview" }

    public var appPath: String { root + "/" + appName + ".app" }

    public var databasePath: String { root + "/data/unifieddev.sqlite" }

    public var workspacesRoot: String { root + "/workspaces" }

    public var scratchRoot: String { Self.scratch(in: root) }

    public static func scratch(in root: String) -> String { root + "/scratch" }

    public var tmuxSocket: String { TmuxSessions.socketName(databasePath: databasePath) }

    public var bridgeServerName: String {
        BridgeRegistration.ownerServerName(forBundleIdentifier: bundleIdentifier)
    }

    public var fields: [(key: String, value: String)] {
        [
            ("slug", slug),
            ("issue", issue.map(String.init) ?? ""),
            ("label", label),
            ("bundle_id", bundleIdentifier),
            ("app_name", appName),
            ("title_prefix", windowTitlePrefix),
            ("url_scheme", urlScheme),
            ("services_item", servicesMenuItem),
            ("root", root),
            ("app_path", appPath),
            ("database", databasePath),
            ("workspaces", workspacesRoot),
            ("scratch", scratchRoot),
            ("tmux_socket", tmuxSocket),
            ("bridge_server", bridgeServerName),
        ]
    }

    public static func isPreview(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier, bundleIdentifier.hasPrefix(bundlePrefix) else { return false }
        let rest = bundleIdentifier.dropFirst(bundlePrefix.count)
        return !rest.isEmpty && BridgeRegistration.slugified(String(rest)) == rest
    }

    static func issue(fromBranch branch: String) -> Int? {
        let leaf = branch.split(separator: "/").last.map(String.init) ?? branch
        let digits = leaf.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, leaf.dropFirst(digits.count).first.map({ $0 == "-" }) ?? true else {
            return nil
        }
        return Int(digits)
    }

    static func cleanLabel(_ value: String?) -> String {
        let words = (value ?? "").components(separatedBy: .whitespacesAndNewlines)
            .map { $0.filter { !$0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } } }
            .filter { !$0.isEmpty }
        let joined = words.joined(separator: " ")
        guard joined.count > labelLimit else { return joined }
        return String(joined.prefix(labelLimit - 1)).trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }
}

public enum PreviewIdentityError: Error, CustomStringConvertible, Equatable {
    case noSlug(String)

    public var description: String {
        switch self {
        case .noSlug(let path):
            "\(path) is not an absolute worktree path with a name to derive a preview identity from"
        }
    }
}
