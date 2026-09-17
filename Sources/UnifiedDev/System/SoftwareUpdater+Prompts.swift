import AppKit
import Core

extension SoftwareUpdater {
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

    func showFailure(_ detail: String, release: GitHubRelease, title: String = SoftwareUpdate.failureTitle) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: SoftwareUpdate.releasePageButtonTitle)
        alert.addButton(withTitle: SoftwareUpdate.laterButtonTitle)
        guard alert.runModal() == .alertFirstButtonReturn, GitHubRelease.isGitHubURL(release.pageURL) else { return }
        NSWorkspace.shared.open(release.pageURL)
    }

    func showAlert(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}
