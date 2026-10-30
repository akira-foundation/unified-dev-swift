import AppKit
import Core

extension SoftwareUpdater {
    static func alert(for prompt: SoftwareUpdate.Prompt) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = prompt.title
        alert.informativeText = prompt.detail
        if !prompt.notes.isEmpty {
            alert.accessoryView = notesView(prompt.notes)
        }
        for button in prompt.buttons {
            alert.addButton(withTitle: button.title).keyEquivalent = button == prompt.defaultButton ? "\r" : ""
        }
        return alert
    }

    func answer(to prompt: SoftwareUpdate.Prompt) -> SoftwareUpdate.Prompt.Button {
        let chosen = Self.alert(for: prompt).runModal().rawValue
            - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard prompt.buttons.indices.contains(chosen) else { return prompt.defaultButton }
        return prompt.buttons[chosen]
    }

    private static func showTop(of scroll: NSScrollView) {
        scroll.documentView?.scroll(.zero)
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private static func notesView(_ notes: String) -> NSView {
        let width: CGFloat = 420
        let inset: CGFloat = 4
        let font = NSFont.preferredFont(forTextStyle: .body)
        let measured = NSAttributedString(string: notes, attributes: [.font: font])
            .boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            .height
        let visible = min(max(measured.rounded(.up), 48), 232) + inset * 2

        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: visible))
        text.string = notes
        text.font = font
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        text.textContainerInset = NSSize(width: 0, height: inset)
        text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.setAccessibilityLabel(SoftwareUpdate.notesLabel)
        text.setAccessibilityRole(.textArea)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: visible))
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.setAccessibilityLabel(SoftwareUpdate.notesLabel)
        showTop(of: scroll)
        DispatchQueue.main.async { showTop(of: scroll) }
        return scroll
    }

    func installNowWasChosen(running: Int, workspaceNames: [String]) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = SoftwareUpdate.interruptionTitle(runningCount: running)
        alert.informativeText = SoftwareUpdate.interruptionDetail(
            runningCount: running,
            workspaceNames: workspaceNames
        )
        alert.addButton(withTitle: SoftwareUpdate.installButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.laterButtonTitle)
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
        return alert.runModal() == .alertFirstButtonReturn
    }

    func showFailure(_ detail: String, release: GitHubRelease) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = SoftwareUpdate.failureTitle
        alert.informativeText = detail
        alert.addButton(withTitle: SoftwareUpdate.releasePageButtonTitle).keyEquivalent = ""
        alert.addButton(withTitle: SoftwareUpdate.laterButtonTitle).keyEquivalent = "\r"
        guard alert.runModal() == .alertFirstButtonReturn, GitHubRelease.isGitHubURL(release.pageURL) else { return }
        NSWorkspace.shared.open(release.pageURL)
    }

    func showAlert(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: SoftwareUpdate.closeButtonTitle)
        alert.runModal()
    }
}
