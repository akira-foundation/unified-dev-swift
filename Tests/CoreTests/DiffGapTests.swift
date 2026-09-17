import Testing
@testable import Core

@Suite("Gaps between hunks")
struct DiffGapTests {
    private func hunk(newStart: Int, newCount: Int) -> DiffHunk {
        DiffHunk(
            oldStart: newStart, oldCount: newCount,
            newStart: newStart, newCount: newCount,
            header: "", lines: []
        )
    }

    @Test("the first gap starts at the top of the file")
    func theFirstGapReachesLineOne() {
        let hunks = [hunk(newStart: 10, newCount: 4)]
        #expect(DiffGap.between(hunks: hunks, at: 0) == 1..<10)
    }

    @Test("a later gap starts where the hunk before it ended")
    func aLaterGapStartsAtThePreviousEnd() {
        let hunks = [hunk(newStart: 1, newCount: 5), hunk(newStart: 20, newCount: 3)]
        #expect(DiffGap.between(hunks: hunks, at: 1) == 6..<20)
    }

    @Test("touching hunks have no gap at all")
    func touchingHunksHaveNoGap() {
        let hunks = [hunk(newStart: 1, newCount: 9), hunk(newStart: 10, newCount: 3)]
        #expect(DiffGap.between(hunks: hunks, at: 1) == nil)
        #expect(DiffGap.between(hunks: [hunk(newStart: 1, newCount: 4)], at: 0) == nil)
        #expect(DiffGap.between(hunks: [], at: 0) == nil)
        #expect(DiffGap.between(hunks: hunks, at: 7) == nil)
    }

    @Test("lines are revealed upward from the hunk")
    func revealedUpward() {
        let gap = 1..<20
        #expect(DiffGap.revealed(5, in: gap) == 15..<20)
        #expect(DiffGap.revealed(0, in: gap).isEmpty)
    }

    @Test("revealing more than the gap holds stops at the gap")
    func revealingIsClamped() {
        let gap = 6..<20
        #expect(DiffGap.revealed(500, in: gap) == gap)
        #expect(DiffGap.revealed(-3, in: gap).isEmpty)
    }

    @Test("hidden and revealed always account for the whole gap")
    func hiddenIsTheRest() {
        let gap = 1..<25
        for requested in [0, 1, 12, 24, 99] {
            #expect(
                DiffGap.hidden(requested, in: gap) + DiffGap.revealed(requested, in: gap).count
                    == gap.count
            )
        }
    }

    @Test("the lines drawn and the lines a comment may anchor to are the same lines")
    func bothHalvesAgree() throws {
        let hunks = [hunk(newStart: 1, newCount: 5), hunk(newStart: 40, newCount: 6)]
        let gap = try #require(DiffGap.between(hunks: hunks, at: 1))
        #expect(DiffGap.revealed(12, in: gap) == DiffGap.revealed(12, in: gap))
        #expect(DiffGap.revealed(12, in: gap).upperBound == hunks[1].newStart)
    }
}
