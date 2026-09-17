import AppKit
import UniformTypeIdentifiers

@MainActor
enum ApplicationPicker {
    static func choose() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = "Add"
        panel.message = "Choose an application to offer in the Open in menus."
        guard await panel.present() == .OK, let url = panel.url else { return nil }
        return url
    }
}
