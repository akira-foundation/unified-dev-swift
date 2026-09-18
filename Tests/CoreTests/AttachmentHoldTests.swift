import Testing
@testable import Core

@Suite("Attachment hold")
struct AttachmentHoldTests {
    static let first = ".unifieddev/attachments/9JVKW4/shot.png"
    static let second = ".unifieddev/attachments/aB3xZ9/Pasted 2026-08-20 at 22.29.20.png"
    static let inWorktree = "Sources/UnifiedDev/Views/Center/ComposerView.swift"

    @Test("A held file whose token was removed is reported as unnamed")
    func removedTokenIsUnnamed() {
        let draft = "compare `\(Self.first)` with this"
        #expect(AttachmentDraft.unnamed([Self.first, Self.second], in: draft) == [Self.second])
    }

    @Test("A held file the draft still names is not reported")
    func presentTokenIsNamed() {
        let draft = "`\(Self.first)` and `\(Self.second)`"
        #expect(AttachmentDraft.unnamed([Self.first, Self.second], in: draft).isEmpty)
    }

    @Test("A file named twice stays named while one copy of its token is left")
    func repeatedPathStaysNamedUntilTheLastCopy() {
        let twice = "`\(Self.first)` then again `\(Self.first)`"
        let parsed = AttachmentDraft.parse(twice)
        let once = parsed.removing(attachment: 0)
        let none = AttachmentDraft.parse(once).removing(attachment: 0)

        #expect(AttachmentDraft.unnamed([Self.first], in: once).isEmpty)
        #expect(AttachmentDraft.unnamed([Self.first], in: none) == [Self.first])
    }

    @Test("A slash command prefix does not hide or invent a token")
    func slashCommandPrefix() {
        let draft = "/review `\(Self.first)` this one"
        #expect(AttachmentDraft.unnamed([Self.first, Self.second], in: draft) == [Self.second])
        #expect(AttachmentDraft.unnamed([Self.first], in: "/review") == [Self.first])
    }

    @Test("A file inside the worktree is recognised through the held list")
    func heldPathOutsideTheAttachmentsFolder() {
        let draft = "look at `\(Self.inWorktree)`"
        #expect(AttachmentDraft.unnamed([Self.inWorktree], in: draft).isEmpty)
        #expect(AttachmentDraft.unnamed([Self.inWorktree], in: "look at nothing") == [Self.inWorktree])
    }

    @Test("Editing releases what the draft stopped naming and adopts nothing")
    func editingReleases() {
        let hold = AttachmentHold.editing(
            active: [Self.first, Self.second], released: [], in: "`\(Self.first)` only"
        )
        #expect(hold == AttachmentHold(releasing: [Self.second]))
        #expect(hold.changesHold)
    }

    @Test("Mounting adopts an unnamed file nobody released and releases nothing")
    func mountingAdoptsUnreleased() {
        let hold = AttachmentHold.mounting(
            active: [Self.first, Self.second], released: [], in: "`\(Self.first)` only"
        )
        #expect(hold == AttachmentHold(adopting: [Self.second]))
        #expect(!hold.changesHold)
    }

    @Test("Mounting never brings back a file whose chip was removed")
    func mountingLeavesReleasedAlone() {
        let hold = AttachmentHold.mounting(
            active: [Self.first], released: [Self.second], in: "`\(Self.first)` only"
        )
        #expect(hold == AttachmentHold())
    }

    @Test("A released file named again, as undo does, is reinstated")
    func undoReinstates() {
        let draft = "`\(Self.first)` and `\(Self.second)`"
        let editing = AttachmentHold.editing(active: [Self.first], released: [Self.second], in: draft)
        let mounting = AttachmentHold.mounting(active: [Self.first], released: [Self.second], in: draft)

        #expect(editing == AttachmentHold(reinstating: [Self.second]))
        #expect(mounting == AttachmentHold(reinstating: [Self.second]))
    }

    @Test("An empty draft releases every held file while editing")
    func emptiedDraftReleasesEverything() {
        let hold = AttachmentHold.editing(active: [Self.first, Self.second], released: [], in: "")
        #expect(hold.releasing == [Self.first, Self.second])
    }
}
