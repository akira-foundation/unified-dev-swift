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

    @Test("another key with Option is not this key", arguments: [UInt16(36), 49, 53, 125, 126, 0])
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

    @Test("the alternate key agrees with the stroke the monitor reads")
    func catalogueAndStrokeAgree() {
        guard let alternate = MenuBarCatalogue[.nextTab].alternateKey else {
            Issue.record("Next Tab has no alternate key")
            return
        }

        #expect(alternate.trigger == .tab)
        #expect(
            TabCycleStroke.offset(
                keyCode: TabCycleStroke.keyCode,
                hasOption: alternate.modifiers.contains(.option),
                hasShift: alternate.modifiers.contains(.shift),
                hasCommand: false,
                hasControl: false
            ) == 1
        )
    }
}
