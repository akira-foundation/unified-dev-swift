import Foundation

public enum GlobalWorkspaceSettings {
    public static var file: String { "\(SettingsLoader.homeDirectory)/.unifieddev/settings.toml" }

    public static func deleteBranchOnArchive(paths: [String] = SettingsLoader.homePaths()) -> Bool {
        SettingsLoader.loadHome(paths: paths).deleteBranchOnArchive
    }

    public static func setDeleteBranchOnArchive(_ flag: Bool, in file: String = file) throws {
        try set(flag, at: .deleteBranchOnArchive, in: file)
    }

    public static func archiveOnMerge(paths: [String] = SettingsLoader.homePaths()) -> Bool {
        SettingsLoader.loadHome(paths: paths).archiveOnMerge
    }

    public static func setArchiveOnMerge(_ flag: Bool, in file: String = file) throws {
        try set(flag, at: .archiveOnMerge, in: file)
    }

    private static func set(_ flag: Bool, at key: SettingsKey, in file: String) throws {
        let target = URL(fileURLWithPath: file).resolvingSymlinksInPath().path
        let exists = FileManager.default.fileExists(atPath: target)
        let text = exists ? try String(contentsOfFile: target, encoding: .utf8) : ""
        var document = SettingsDocument(text: text, exists: exists)
        document.set(.boolean(flag), at: key.path)
        try document.write(to: target)
    }
}
