import AppKit
import Core

@MainActor
enum DocumentPreviewExit {
    static func confirm(_ url: URL) -> Bool {
        let prompt = DocumentPreviewExitPrompt.asking(about: url)
        let alert = NSAlert()
        alert.messageText = prompt.title
        alert.informativeText = prompt.message
        alert.alertStyle = .warning
        alert.addButton(withTitle: prompt.confirm)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
