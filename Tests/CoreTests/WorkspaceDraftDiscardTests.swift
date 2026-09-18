import Foundation
import Testing
@testable import Core

@Suite("Escape in a new workspace draft")
struct WorkspaceDraftDiscardTests {
    @Test("an empty draft goes at once, one with text asks first")
    func asksOnlyWhenThereIsText() {
        #expect(WorkspaceDraftDiscard.onEscape(hasContent: false, isCreating: false) == .discard)
        #expect(WorkspaceDraftDiscard.onEscape(hasContent: true, isCreating: false) == .confirm)
    }

    @Test("a draft being created is left alone, whatever it holds")
    func creatingIsLeftAlone() {
        #expect(WorkspaceDraftDiscard.onEscape(hasContent: true, isCreating: true) == .ignore)
        #expect(WorkspaceDraftDiscard.onEscape(hasContent: false, isCreating: true) == .ignore)
    }

    @Test("the question names what goes and offers a way to keep it")
    func wording() {
        #expect(WorkspaceDraftDiscard.title == "Discard this draft?")
        #expect(WorkspaceDraftDiscard.confirmLabel == "Discard Draft")
        #expect(WorkspaceDraftDiscard.cancelLabel == "Keep Writing")
        #expect(!WorkspaceDraftDiscard.message.isEmpty)
    }
}
