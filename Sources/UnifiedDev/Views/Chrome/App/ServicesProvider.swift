import AppKit
import Core

@MainActor
final class ServicesProvider: NSObject {
    private weak var app: AppModel?

    func attach(_ model: AppModel) {
        app = model
    }

    @objc(createWorkspaceFromSelection:userData:error:)
    func createWorkspaceFromSelection(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            error.pointee = "There was no text to start a workspace from." as NSString
            return
        }

        guard let app, !app.repos.isEmpty else {
            error.pointee = "Add a project folder to Unified Dev before starting a workspace." as NSString
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        MainWindow.raise()
        app.openDraft(prompt: text)
    }
}
