import Testing
@testable import Core

@Suite("Whether a list draws its focus ring")
struct ListFocusTests {
    @Test("a list with no keyboard draws nothing, however it lost it")
    func withoutKeyboard() {
        #expect(!ListFocus(hasKeyboard: false, origin: .keyboard).showsRing)
        #expect(!ListFocus(hasKeyboard: false, origin: .mouse).showsRing)
        #expect(
            !ListFocus(hasKeyboard: false, origin: .keyboard, fullKeyboardAccess: true).showsRing
        )
    }

    @Test("a click is silent")
    func mouseIsSilent() {
        #expect(!ListFocus(hasKeyboard: true, origin: .mouse).showsRing)
    }

    @Test("a key press draws it")
    func keyboardDrawsIt() {
        #expect(ListFocus(hasKeyboard: true, origin: .keyboard).showsRing)
    }

    @Test("focus from nowhere draws it")
    func unknownDrawsIt() {
        #expect(ListFocus(hasKeyboard: true, origin: .unknown).showsRing)
    }

    @Test("Full Keyboard Access draws it even for a click")
    func fullKeyboardAccessDrawsIt() {
        #expect(ListFocus(hasKeyboard: true, origin: .mouse, fullKeyboardAccess: true).showsRing)
    }

    @Test("a click promoted by a key press draws it")
    func promotion() {
        var focus = ListFocus(hasKeyboard: true, origin: .mouse)
        #expect(!focus.showsRing)
        focus.origin = .keyboard
        #expect(focus.showsRing)
    }

    @Test("the default is a list nobody is pointed at")
    func defaults() {
        #expect(!ListFocus().showsRing)
        #expect(!ListFocus().hasKeyboard)
    }
}
