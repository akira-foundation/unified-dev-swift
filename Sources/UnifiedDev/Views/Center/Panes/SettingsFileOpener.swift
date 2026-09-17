import AppKit
import Core

@MainActor
enum SettingsFileOpener {
    static func open(_ path: String, repo: RepoID) {
        if let app = OpenIn.preferred(for: .file(path), repo: repo) {
            OpenIn.open(path, with: app, repo: repo)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
        }
    }
}
