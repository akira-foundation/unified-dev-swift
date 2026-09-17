import AppKit
import Core

@MainActor
enum TerminalPaneMenu {
    static func make(
        canClose: Bool,
        isZoomed: Bool,
        onAddToChat: (@MainActor () -> Void)? = nil,
        perform: @escaping @MainActor (TerminalPaneCommand) -> Void
    ) -> NSMenu {
        let target = ActionTarget(perform: perform, onAddToChat: onAddToChat)
        let menu = OwningMenu(target: target)
        menu.autoenablesItems = false

        let addToChat = NSMenuItem(title: "Add to Chat", action: #selector(ActionTarget.addToChat), keyEquivalent: "")
        addToChat.target = target
        addToChat.isEnabled = onAddToChat != nil
        menu.addItem(addToChat)
        menu.addItem(.separator())

        menu.addItem(splitItem(
            "Split Right", symbol: PaneSymbol.splitRight, axis: .horizontal,
            key: "d", modifiers: .command, target: target
        ))
        menu.addItem(splitItem(
            "Split Down", symbol: PaneSymbol.splitDown, axis: .vertical,
            key: "d", modifiers: [.command, .shift], target: target
        ))

        menu.addItem(.separator())

        menu.addItem(item(
            isZoomed ? "Zoom Out" : "Zoom Pane",
            symbol: isZoomed ? PaneSymbol.zoomOut : PaneSymbol.zoomIn,
            key: "\r", modifiers: [.command, .shift],
            command: .toggleZoom, target: target
        ))

        menu.addItem(.separator())

        let close = item(
            "Close Pane", symbol: PaneSymbol.closePane, key: "w", modifiers: .command,
            command: .close, target: target
        )
        close.isEnabled = canClose
        menu.addItem(close)

        return menu
    }

    private static func splitItem(
        _ title: String,
        symbol: String,
        axis: SplitAxis,
        key: String,
        modifiers: NSEvent.ModifierFlags,
        target: ActionTarget
    ) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = PaneSymbol.image(symbol, label: title)

        let kinds = NSMenu(title: title)
        for kind in PaneKind.allCases {
            let carriesShortcut = kind == .terminal
            kinds.addItem(item(
                kind.title,
                symbol: kind.symbol,
                key: carriesShortcut ? key : "",
                modifiers: carriesShortcut ? modifiers : [],
                command: .split(axis, kind),
                target: target
            ))
        }
        parent.submenu = kinds
        return parent
    }

    private static func item(
        _ title: String,
        symbol: String,
        key: String,
        modifiers: NSEvent.ModifierFlags,
        command: TerminalPaneCommand,
        target: ActionTarget
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(ActionTarget.fire(_:)), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.image = PaneSymbol.image(symbol, label: title)
        item.target = target
        item.represent(command)
        return item
    }

    @MainActor
    final class ActionTarget: NSObject {
        private let perform: @MainActor (TerminalPaneCommand) -> Void
        private let onAddToChat: (@MainActor () -> Void)?

        init(perform: @escaping @MainActor (TerminalPaneCommand) -> Void, onAddToChat: (@MainActor () -> Void)?) {
            self.perform = perform
            self.onAddToChat = onAddToChat
        }

        @objc func addToChat() { onAddToChat?() }

        @objc func fire(_ sender: NSMenuItem) {
            guard let command = sender.represented(TerminalPaneCommand.self) else { return }
            perform(command)
        }
    }
}

private final class OwningMenu: NSMenu {
    private let target: TerminalPaneMenu.ActionTarget

    init(target: TerminalPaneMenu.ActionTarget) {
        self.target = target
        super.init(title: "")
    }

    required init(coder: NSCoder) {
        fatalError("OwningMenu is only ever built in code")
    }
}
