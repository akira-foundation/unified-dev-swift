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

@Suite("What a draft holds")
struct WorkspaceDraftWorkTests {
    @Test("a draft with only attachments still holds work, an untouched one does not")
    func attachmentsAreWork() {
        let draft = WorkspaceDraft(repoID: RepoID("r"), startingPoint: .newBranch(from: "main"))
        #expect(!draft.holdsWork(attachmentCount: 0))
        #expect(draft.holdsWork(attachmentCount: 2))
        var written = draft
        written.prompt = "Ring the bell"
        #expect(written.holdsWork(attachmentCount: 0))
    }

    @Test("only a plain short id is a staging key, never a path")
    func stagingKeys() {
        #expect(WorkspaceDraft.isStagingKey(PromptAttachments.newShortID()))
        #expect(WorkspaceDraft.isStagingKey("k1"))
        #expect(!WorkspaceDraft.isStagingKey(""))
        #expect(!WorkspaceDraft.isStagingKey("../../.."))
        #expect(!WorkspaceDraft.isStagingKey("a/b"))
        #expect(!WorkspaceDraft.isStagingKey(String(repeating: "a", count: 65)))
    }
}
