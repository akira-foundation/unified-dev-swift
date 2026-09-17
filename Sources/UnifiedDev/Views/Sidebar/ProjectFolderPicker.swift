import AppKit

@MainActor
enum ProjectFolderPicker {
    static func choose() async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Add project"
        panel.message = "Choose the folder you want to run agents in."
        guard await panel.present() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}

extension ProjectFolderPicker {
    static func chooseTarget(
        startingAt path: String?,
        message: String = "Choose the folder your project should live in."
    ) async -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = message
        if let path, FileManager.default.fileExists(atPath: path) {
            panel.directoryURL = URL(fileURLWithPath: path)
        }
        guard await panel.present() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}
