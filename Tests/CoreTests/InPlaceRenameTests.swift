import Testing
@testable import Core

@Suite("Ending an in-place rename")
struct InPlaceRenameTests {
    @Test("every ending but Escape writes the name")
    func endingsThatCommit() {
        for ending in InPlaceRename.Ending.allCases where ending != .escaped {
            #expect(
                InPlaceRename.outcome(ending, draft: "new name", current: "old name")
                    == .commit("new name"),
                "\(ending)"
            )
        }
    }

    @Test("a field closed from underneath still writes")
    func dismissed() {
        #expect(
            InPlaceRename.outcome(.dismissed, draft: "renamed", current: "old")
                == .commit("renamed")
        )
    }

    @Test("Escape throws the draft away")
    func escape() {
        #expect(InPlaceRename.outcome(.escaped, draft: "typed", current: "old") == .discard)
    }

    @Test("surrounding space is not part of the name")
    func trimming() {
        #expect(
            InPlaceRename.outcome(.submitted, draft: "  spaced  ", current: "old")
                == .commit("spaced")
        )
        #expect(InPlaceRename.outcome(.focusLost, draft: "   ", current: "old") == .discard)
        #expect(InPlaceRename.outcome(.submitted, draft: "", current: "old") == .discard)
    }

    @Test("an unchanged name writes nothing")
    func unchanged() {
        #expect(InPlaceRename.outcome(.submitted, draft: "old", current: "old") == .discard)
        #expect(InPlaceRename.outcome(.focusLost, draft: " old ", current: "old") == .discard)
    }
}
