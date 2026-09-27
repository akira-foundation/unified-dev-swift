import Testing
@testable import Core

@Suite("When a hunk can be discarded")
struct HunkDiscardTests {
    private func offer(
        _ change: ChangedFile.Change, binary: Bool = false, whitespace: Bool = false,
        blocker: String? = nil, unsaved: Bool = false
    ) -> HunkDiscard.Availability {
        HunkDiscard.availability(
            file: ChangedFile(path: "a.txt", change: change, isBinary: binary),
            ignoringWhitespace: whitespace, blocker: blocker, hasUnsavedEdits: unsaved
        )
    }

    @Test("only a change within a file offers a hunk discard")
    func changesWithinAFile() {
        #expect(offer(.modified) == .enabled)
        #expect(offer(.renamed) == .enabled)
        #expect(offer(.copied) == .hidden)
        #expect(offer(.added) == .hidden)
        #expect(offer(.deleted) == .hidden)
        #expect(offer(.untracked) == .hidden)
        #expect(offer(.modified, binary: true) == .hidden)
    }

    @Test("a turn in progress, unsaved edits and hidden whitespace disable it with a reason, in that order")
    func disabledWithAReason() {
        let turn = FileBarControls.revertWhileAgentWorks
        #expect(offer(.modified, blocker: turn) == .disabled(turn))
        #expect(offer(.modified, unsaved: true) == .disabled(HunkDiscard.draftIsOpen))
        #expect(offer(.modified, whitespace: true) == .disabled(HunkDiscard.whitespaceIsHidden))
        #expect(offer(.modified, whitespace: true, blocker: turn, unsaved: true) == .disabled(turn))
        #expect(offer(.modified, whitespace: true, unsaved: true) == .disabled(HunkDiscard.draftIsOpen))
        #expect(offer(.added, blocker: turn) == .hidden)
    }

    @Test("the question names the path")
    func question() {
        #expect(HunkDiscard.question(path: "app/Handler.php") == "Discard this hunk in app/Handler.php?")
    }

    @Test("the losses count what is put back and what is taken out")
    func losses() {
        let hunk = DiffHunk(oldStart: 1, oldCount: 2, newStart: 1, newCount: 3, lines: [
            DiffLine(kind: .context, text: "a"),
            DiffLine(kind: .deletion, text: "b"),
            DiffLine(kind: .addition, text: "B"),
            DiffLine(kind: .addition, text: "C"),
        ])
        #expect(HunkDiscard.losses(of: hunk)
            == "This puts back 1 removed line and takes out 2 added lines. "
            + "The rest of the file is left as it is.\n\nThere is no undo for this.")
    }

    @Test("a hunk with nothing counted still says what happens")
    func lossesWithoutCounts() {
        let hunk = DiffHunk(oldStart: 1, oldCount: 1, newStart: 1, newCount: 1, lines: [
            DiffLine(kind: .context, text: "a"),
        ])
        #expect(HunkDiscard.losses(of: hunk).hasPrefix("This undoes the change. "))
    }

    @Test("every refusal says nothing was discarded, and git's words follow when there are some")
    func refusals() {
        let changed = HunkDiscardRefusal.changed.errorDescription ?? ""
        let bare = HunkDiscardRefusal.doesNotApply("").errorDescription ?? ""
        let detailed = HunkDiscardRefusal.doesNotApply("error: patch failed").errorDescription ?? ""
        #expect(changed.hasSuffix("Nothing was discarded."))
        #expect(bare == "The hunk no longer applies cleanly, so nothing was discarded.")
        #expect(detailed == bare + "\n\nerror: patch failed")
        #expect(HunkDiscardRefusal.notOffered.errorDescription?.isEmpty == false)
    }
}
