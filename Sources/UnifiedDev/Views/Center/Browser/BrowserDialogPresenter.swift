import AppKit
import Core

struct BrowserDialogAnswer {
    var isConfirmed: Bool
    var text: String?
    var isSilenced = false

    static let dismissed = BrowserDialogAnswer(isConfirmed: false, text: nil)
}

@MainActor
final class BrowserDialogPresenter {
    private var live: (alert: NSAlert, host: NSWindow)?

    private var field: NSTextField?

    func ask(
        _ kind: BrowserDialogs.Kind,
        _ presentation: BrowserDialogs.Presentation,
        over window: NSWindow?
    ) async -> BrowserDialogAnswer {
        guard let window else { return .dismissed }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = presentation.title
        alert.informativeText = presentation.message
        alert.addButton(withTitle: "OK")
        if kind != .alert { alert.addButton(withTitle: "Cancel") }

        if kind == .prompt {
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
            field.stringValue = presentation.defaultText
            field.isEditable = true
            field.isSelectable = true
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            self.field = field
        }

        if presentation.offersSuppression {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Stop this page asking"
        }

        live = (alert, window)
        let response = await alert.beginSheetModal(for: window)
        if live?.alert === alert { live = nil }

        let isConfirmed = response == .alertFirstButtonReturn
        let text = (kind == .prompt && isConfirmed) ? (field?.stringValue ?? "") : nil
        field = nil
        return BrowserDialogAnswer(
            isConfirmed: isConfirmed,
            text: text,
            isSilenced: alert.suppressionButton?.state == .on
        )
    }

    func dismiss() {
        guard let live else { return }
        self.live = nil
        live.host.endSheet(live.alert.window, returnCode: .cancel)
    }
}
