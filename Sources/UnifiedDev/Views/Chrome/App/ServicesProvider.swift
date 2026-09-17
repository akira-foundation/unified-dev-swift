import AppKit
import Core

@MainActor
final class ServicesProvider: NSObject {
    private static let lastRepoKey = "services.lastRepoID"

    private static let width: CGFloat = 380
    private static let textHeight: CGFloat = 110
    private static let gap: CGFloat = 8

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
        guard let (repo, prompt) = confirm(text: text, in: app) else { return }

        UserDefaults.standard.set(repo.id.rawValue, forKey: Self.lastRepoKey)
        MainWindow.raise()
        Task { await app.createWorkspace(in: repo, prompt: prompt) }
    }

    private func confirm(text: String, in app: AppModel) -> (Repo, String)? {
        let projects = NSPopUpButton(
            frame: NSRect(x: 0, y: Self.textHeight + Self.gap, width: Self.width, height: 25),
            pullsDown: false
        )
        for repo in app.repos { projects.addItem(withTitle: repo.name) }
        projects.selectItem(at: defaultRepoIndex(in: app))

        let scroller = NSScrollView(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.textHeight))
        scroller.hasVerticalScroller = true
        scroller.borderType = .bezelBorder

        let field = NSTextView(frame: scroller.contentView.bounds)
        field.string = text
        field.font = .preferredFont(forTextStyle: .body)
        field.isRichText = false
        field.isVerticallyResizable = true
        field.autoresizingMask = [.width]
        field.textContainer?.containerSize = NSSize(
            width: scroller.contentView.bounds.width, height: .greatestFiniteMagnitude
        )
        field.textContainer?.widthTracksTextView = true
        scroller.documentView = field

        let accessory = NSView(frame: NSRect(
            x: 0, y: 0, width: Self.width, height: Self.textHeight + Self.gap + 25
        ))
        accessory.addSubview(projects)
        accessory.addSubview(scroller)

        let alert = NSAlert()
        alert.messageText = "Start a workspace from this text?"
        alert.informativeText = "Unified Dev cuts a branch and a worktree, then sends this to the agent."
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Create Workspace")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let index = projects.indexOfSelectedItem
        guard index >= 0, index < app.repos.count else { return nil }
        let prompt = field.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return nil }
        return (app.repos[index], prompt)
    }

    private func defaultRepoIndex(in app: AppModel) -> Int {
        let remembered = UserDefaults.standard.string(forKey: Self.lastRepoKey).map(RepoID.init)
        let selected = app.selectedWorkspace.flatMap { app.repo(for: $0) }?.id
        for candidate in [remembered, selected] {
            if let candidate, let index = app.repos.firstIndex(where: { $0.id == candidate }) {
                return index
            }
        }
        return 0
    }
}
