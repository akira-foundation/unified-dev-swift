import Foundation
import Testing
@testable import Core

@Suite("The key that cycles the centre tabs")
struct TabCycleStrokeTests {
    private func offset(
        _ keyCode: UInt16 = TabCycleStroke.keyCode,
        option: Bool = true,
        shift: Bool = false,
        command: Bool = false,
        control: Bool = false
    ) -> Int? {
        TabCycleStroke.offset(
            keyCode: keyCode, hasOption: option, hasShift: shift,
            hasCommand: command, hasControl: control
        )
    }

    @Test("Option and Tab goes forward, and Option Shift Tab goes back")
    func bothDirections() {
        #expect(offset() == 1)
        #expect(offset(shift: true) == -1)
    }

    @Test("Tab on its own belongs to whatever has the keyboard")
    func plainTabIsNotOurs() {
        #expect(offset(option: false) == nil)
        #expect(offset(option: false, shift: true) == nil)
    }

    @Test("Option with anything else on top is not this key")
    func moreModifiersAreNotOurs() {
        #expect(offset(command: true) == nil)
        #expect(offset(control: true) == nil)
        #expect(offset(command: true, control: true) == nil)
    }

    @Test(
        "another key with Option is not this key",
        arguments: [UInt16(36), 49, 53, 123, 124, 125, 126, 0]
    )
    func otherKeysAreNotOurs(keyCode: UInt16) {
        #expect(offset(keyCode) == nil)
    }

    @Test("the catalogue is where the key is written down, once")
    func theCatalogueOwnsTheKey() {
        let next = MenuBarCatalogue[.nextTab]
        let previous = MenuBarCatalogue[.previousTab]

        #expect(next.alternateKey?.trigger == .tab)
        #expect(next.alternateKey?.modifiers == [.option])
        #expect(previous.alternateKey?.trigger == .tab)
        #expect(previous.alternateKey?.modifiers == [.option, .shift])
        #expect(next.key?.trigger == .character("]"))
    }

    @Test("the stroke answers exactly the alternate keys the catalogue declares")
    func strokeFollowsTheCatalogue() {
        for direction in TabCycleStroke.directions {
            guard let alternate = MenuBarCatalogue[direction.action].alternateKey else {
                Issue.record("\(direction.action) has no alternate key")
                continue
            }

            #expect(alternate.trigger == .tab, "\(direction.action)")
            #expect(
                TabCycleStroke.offset(
                    keyCode: TabCycleStroke.keyCode,
                    hasOption: alternate.modifiers.contains(.option),
                    hasShift: alternate.modifiers.contains(.shift),
                    hasCommand: false,
                    hasControl: false
                ) == direction.offset,
                "\(direction.action)"
            )
        }
    }

    @Test(
        "only the modifier combinations the catalogue declares answer",
        arguments: [[], [MenuShortcut.Modifiers.option], [.shift], [.option, .shift]] as [MenuShortcut.Modifiers]
    )
    func onlyDeclaredModifiersAnswer(modifiers: MenuShortcut.Modifiers) {
        let declared = TabCycleStroke.directions.compactMap { direction -> (MenuShortcut.Modifiers, Int)? in
            MenuBarCatalogue[direction.action].alternateKey.map { ($0.modifiers, direction.offset) }
        }
        let expected = declared.first { $0.0 == modifiers }?.1

        let answer = TabCycleStroke.offset(
            keyCode: TabCycleStroke.keyCode,
            hasOption: modifiers.contains(.option),
            hasShift: modifiers.contains(.shift),
            hasCommand: false,
            hasControl: false
        )

        #expect(answer == expected, "\(modifiers.rawValue)")
    }

    @Test("the terminal's own Option keys are not taken, only Tab")
    func theTerminalKeepsItsOtherOptionKeys() {
        let arrows: [UInt16] = [123, 124, 125, 126]

        for keyCode in arrows {
            #expect(offset(keyCode) == nil, "Option alone on \(keyCode)")
            #expect(offset(keyCode, command: true) == nil, "Option and Command on \(keyCode)")
        }
    }
}
