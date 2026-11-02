import AppKit
import Core

@MainActor
enum MessageContextMenu {
    static func present(
        for row: TranscriptRow,
        selection: String?,
        transcript: TranscriptModel,
        event: NSEvent,
        in view: NSView
    ) {
        let menu = ActionMenu()
        menu.autoenablesItems = false
        let markdown = MessageCopyText.markdown(kind: row.kind, payload: row.payload)
        let plain = MessageCopyText.plain(kind: row.kind, payload: row.payload)

        menu.add("Copy", key: "c", modifiers: .command, enabled: selection != nil) {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
        }
        menu.addItem(.separator())
        menu.add("Copy message", enabled: plain != nil) { plain.map(Clipboard.copy) }
        menu.add("Copy message as Markdown", enabled: markdown != nil) { markdown.map(Clipboard.copy) }
        menu.addItem(.separator())
        menu.add("Attach selection as context", key: "l", modifiers: [.command, .shift], enabled: selection != nil) {
            selection.map(transcript.reply(with:))
        }

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
}

@MainActor
private final class ActionMenu: NSMenu {
    private var actions: [ActionItem] = []

    init() { super.init(title: "") }

    required init(coder: NSCoder) {
        fatalError("ActionMenu is only ever built in code")
    }

    func add(
        _ title: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        enabled: Bool,
        perform: @escaping @MainActor () -> Void
    ) {
        let action = ActionItem(perform: perform)
        actions.append(action)
        let item = NSMenuItem(title: title, action: #selector(ActionItem.fire), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = action
        item.isEnabled = enabled
        addItem(item)
    }
}

@MainActor
private final class ActionItem: NSObject {
    private let perform: @MainActor () -> Void

    init(perform: @escaping @MainActor () -> Void) { self.perform = perform }

    @objc func fire() { perform() }
}
