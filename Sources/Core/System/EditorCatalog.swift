import Foundation

public struct OpenTargets: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let file = OpenTargets(rawValue: 1 << 0)
    public static let folder = OpenTargets(rawValue: 1 << 1)
    public static let both: OpenTargets = [.file, .folder]
}

public struct ExternalApp: Identifiable, Sendable, Hashable {
    public var id: String { bundleID }
    public let bundleID: String
    public let name: String
    public let targets: OpenTargets
    public let variantIDs: [String]
    public let fileName: String

    public init(
        bundleID: String,
        name: String,
        targets: OpenTargets,
        variantIDs: [String] = [],
        fileName: String? = nil
    ) {
        self.bundleID = bundleID
        self.name = name
        self.targets = targets
        self.variantIDs = variantIDs
        self.fileName = fileName ?? "\(name).app"
    }

    public var bundleIDs: [String] { [bundleID] + variantIDs }

    public func opens(_ target: OpenTargets) -> Bool { targets.contains(target) }

    public func matches(bundleID candidate: String?) -> Bool {
        guard let candidate else { return false }
        if bundleIDs.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) {
            return true
        }
        return Self.isFamilyVariant(candidate, of: bundleID)
    }

    public static func isFamilyVariant(_ candidate: String, of canonical: String) -> Bool {
        let family = "com.jetbrains."
        guard canonical.lowercased().hasPrefix(family) else { return false }
        let lowered = candidate.lowercased()
        guard lowered.hasPrefix(canonical.lowercased()) else { return false }
        let remainder = lowered.dropFirst(canonical.count)
        return !remainder.isEmpty && !remainder.hasPrefix(".")
    }

    public func matchesFileName(_ candidate: String) -> Bool {
        guard candidate.lowercased().hasSuffix(".app") else { return false }
        let stem = String(fileName.dropLast(4))
        guard candidate.lowercased().hasPrefix(stem.lowercased()) else { return false }
        let remainder = candidate.dropFirst(stem.count).dropLast(4)
        guard let first = remainder.first else { return true }
        return !first.isLetter && !first.isNumber
    }
}

public enum EditorCatalog {
    public static let known: [ExternalApp] = [
        ExternalApp(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code", targets: .both),
        ExternalApp(
            bundleID: "com.microsoft.VSCodeInsiders", name: "VS Code Insiders", targets: .both,
            fileName: "Visual Studio Code - Insiders.app"
        ),
        ExternalApp(bundleID: "com.vscodium", name: "VSCodium", targets: .both),
        ExternalApp(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor", targets: .both),
        ExternalApp(bundleID: "com.exafunction.windsurf", name: "Windsurf", targets: .both),
        ExternalApp(bundleID: "dev.zed.Zed", name: "Zed", targets: .both),
        ExternalApp(bundleID: "dev.zed.Zed-Preview", name: "Zed Preview", targets: .both),
        ExternalApp(bundleID: "com.apple.dt.Xcode", name: "Xcode", targets: .both),
        jetBrains("PhpStorm", name: "PhpStorm"),
        jetBrains("WebStorm", name: "WebStorm"),
        jetBrains("intellij", name: "IntelliJ IDEA"),
        ExternalApp(bundleID: "com.jetbrains.intellij.ce", name: "IntelliJ IDEA CE", targets: .both),
        jetBrains("pycharm", name: "PyCharm"),
        ExternalApp(bundleID: "com.jetbrains.pycharm.ce", name: "PyCharm CE", targets: .both),
        jetBrains("rubymine", name: "RubyMine"),
        jetBrains("goland", name: "GoLand"),
        jetBrains("CLion", name: "CLion"),
        jetBrains("rider", name: "Rider"),
        jetBrains("datagrip", name: "DataGrip"),
        jetBrains("rustrover", name: "RustRover"),
        ExternalApp(bundleID: "com.google.android.studio", name: "Android Studio", targets: .both),
        ExternalApp(bundleID: "com.sublimetext.4", name: "Sublime Text", targets: .both),
        ExternalApp(bundleID: "com.panic.Nova", name: "Nova", targets: .both),
        ExternalApp(bundleID: "com.barebones.bbedit", name: "BBEdit", targets: .both),
        ExternalApp(bundleID: "com.macromates.TextMate", name: "TextMate", targets: .both),
        ExternalApp(bundleID: "org.gnu.Emacs", name: "Emacs", targets: .both),
        ExternalApp(bundleID: "org.vim.MacVim", name: "MacVim", targets: .both),

        ExternalApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty", targets: .folder),
        ExternalApp(bundleID: "com.googlecode.iterm2", name: "iTerm", targets: .folder),
        ExternalApp(bundleID: "dev.warp.Warp-Stable", name: "Warp", targets: .folder),
        ExternalApp(bundleID: "net.kovidgoyal.kitty", name: "kitty", targets: .folder),
        ExternalApp(bundleID: "com.github.wez.wezterm", name: "WezTerm", targets: .folder),
        ExternalApp(bundleID: "com.apple.Terminal", name: "Terminal", targets: .folder),

        ExternalApp(bundleID: "com.github.GitHubClient", name: "GitHub Desktop", targets: .folder),
        ExternalApp(bundleID: "com.fournova.Tower3", name: "Tower", targets: .folder),
        ExternalApp(bundleID: "com.sublimemerge", name: "Sublime Merge", targets: .folder),
        ExternalApp(bundleID: "com.DanPristupov.Fork", name: "Fork", targets: .folder),
        ExternalApp(bundleID: "com.axosoft.gitkraken", name: "GitKraken", targets: .folder),
    ]

    private static func jetBrains(_ product: String, name: String) -> ExternalApp {
        let canonical = "com.jetbrains.\(product)"
        return ExternalApp(
            bundleID: canonical,
            name: name,
            targets: .both,
            variantIDs: ["-EAP", "Light", "Light-EAP"].map { canonical + $0 }
        )
    }

    public static let knownIDs = Set(known.map(\.bundleID))

    public static func owner(ofBundleID bundleID: String, in apps: [ExternalApp] = known) -> ExternalApp? {
        if let exact = apps.first(where: { app in
            app.bundleIDs.contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
        }) {
            return exact
        }
        return apps.first { $0.matches(bundleID: bundleID) }
    }

    public static func isKnown(bundleID: String, in apps: [ExternalApp] = known) -> Bool {
        owner(ofBundleID: bundleID, in: apps) != nil
    }

    public static func catalogue(adding custom: [ExternalApp]) -> [ExternalApp] {
        var result = known
        for app in custom where !isKnown(bundleID: app.bundleID, in: result) {
            result.append(app)
        }
        return result
    }

    public static func needsSystemDefaultRow(bundleID: String, adding custom: [ExternalApp]) -> Bool {
        !isKnown(bundleID: bundleID) && !isKnown(bundleID: bundleID, in: custom.filter { $0.opens(.file) })
    }

    public static func installed(_ isInstalled: (String) -> Bool) -> [ExternalApp] {
        known.filter { app in app.bundleIDs.contains(where: isInstalled) }
    }

    public static func opening(_ target: OpenTargets, from apps: [ExternalApp]) -> [ExternalApp] {
        apps.filter { $0.opens(target) }
    }

    public static func ordered(_ apps: [ExternalApp], lastUsed: String?) -> [ExternalApp] {
        guard let lastUsed, let index = apps.firstIndex(where: { $0.bundleID == lastUsed })
        else { return apps }
        var result = apps
        result.insert(result.remove(at: index), at: 0)
        return result
    }
}

public struct OpenInPreferences: @unchecked Sendable {
    public static let globalKey = "openIn.lastUsed"

    public static func key(forRepo id: RepoID) -> String { "openIn.lastUsed.\(id)" }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func lastUsed(repo: RepoID?) -> String? {
        if let repo, let stored = defaults.string(forKey: Self.key(forRepo: repo)) { return stored }
        return defaults.string(forKey: Self.globalKey)
    }

    public func record(_ bundleID: String, repo: RepoID?) {
        defaults.set(bundleID, forKey: Self.globalKey)
        if let repo { defaults.set(bundleID, forKey: Self.key(forRepo: repo)) }
    }
}
