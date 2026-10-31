import Foundation

public enum GlobalWorkspaceSettings {
    public static var file: String { "\(SettingsLoader.homeDirectory)/.unifieddev/settings.toml" }

    public static func deleteBranchOnArchive(paths: [String] = SettingsLoader.homePaths()) -> Bool {
        SettingsLoader.loadHome(paths: paths).deleteBranchOnArchive
    }

    public static func setDeleteBranchOnArchive(_ flag: Bool, in file: String = file) throws {
        let target = URL(fileURLWithPath: file).resolvingSymlinksInPath().path
        let exists = FileManager.default.fileExists(atPath: target)
        let text = exists ? try String(contentsOfFile: target, encoding: .utf8) : ""
        var document = SettingsDocument(text: text, exists: exists)
        document.set(.boolean(flag), at: SettingsKey.deleteBranchOnArchive.path)
        try document.write(to: target)
    }
}
