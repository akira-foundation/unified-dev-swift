import Testing
@testable import Core

@Suite("Menu bar panel keys")
struct MenuBarPanelKeyTests {
    @Test("the panel answers Esc, Command comma, Command Q and Command W", arguments: [
        ("\u{1B}", MenuShortcut.Modifiers(), MenuBarPanelKey.Command.close),
        (",", MenuShortcut.Modifiers.command, MenuBarPanelKey.Command.openSettings),
        ("q", MenuShortcut.Modifiers.command, MenuBarPanelKey.Command.quit),
        ("Q", MenuShortcut.Modifiers.command, MenuBarPanelKey.Command.quit),
        ("w", MenuShortcut.Modifiers.command, MenuBarPanelKey.Command.close),
    ])
    func answers(characters: String, modifiers: MenuShortcut.Modifiers, command: MenuBarPanelKey.Command) {
        #expect(MenuBarPanelKey.command(characters: characters, modifiers: modifiers) == command)
    }

    @Test("anything else is left for the view", arguments: [
        ("q", MenuShortcut.Modifiers()),
        ("q", MenuShortcut.Modifiers([.command, .shift])),
        ("\u{1B}", MenuShortcut.Modifiers.command),
        ("k", MenuShortcut.Modifiers.command),
    ])
    func ignores(characters: String, modifiers: MenuShortcut.Modifiers) {
        #expect(MenuBarPanelKey.command(characters: characters, modifiers: modifiers) == nil)
    }

    @Test("the footer shows the keys the panel answers")
    func shortcuts() {
        #expect(MenuBarPanelKey.shortcut(for: .openSettings)?.display == "\u{2318},")
        #expect(MenuBarPanelKey.shortcut(for: .quit)?.display == "\u{2318}Q")
        #expect(MenuBarPanelKey.shortcut(for: .close) == nil)
    }
}
