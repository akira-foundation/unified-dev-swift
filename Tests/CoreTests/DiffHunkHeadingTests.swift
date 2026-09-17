import Testing
@testable import Core

@Suite("Hunk headings")
struct DiffHunkHeadingTests {
    private func hunk(newStart: Int, newCount: Int, header: String = " func work()") -> DiffHunk {
        DiffHunk(
            oldStart: newStart, oldCount: newCount,
            newStart: newStart, newCount: newCount,
            header: header, lines: []
        )
    }

    @Test("a hunk reached over skipped lines gets a band")
    func skippedLinesEarnABand() {
        let hunks = [hunk(newStart: 1, newCount: 5), hunk(newStart: 40, newCount: 6)]
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 0) == "func work()")
    }

    @Test("the first hunk is judged against the top of the file")
    func theFirstHunkIsJudgedAgainstLineOne() {
        #expect(DiffHunkHeading.text(for: [hunk(newStart: 48, newCount: 6)], at: 0, revealed: 0)
            == "func work()")
        #expect(DiffHunkHeading.text(for: [hunk(newStart: 1, newCount: 6)], at: 0, revealed: 0)
            == nil)
    }

    @Test("a fully revealed gap takes the band with it")
    func aRevealedGapLosesItsBand() {
        let hunks = [hunk(newStart: 1, newCount: 5), hunk(newStart: 49, newCount: 6)]
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 42) != nil)
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 43) == nil)
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 500) == nil)
    }

    @Test("touching hunks get nothing")
    func touchingHunksGetNothing() {
        let hunks = [hunk(newStart: 1, newCount: 9), hunk(newStart: 10, newCount: 3)]
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 0) == nil)
    }

    @Test("a changed scope over contiguous lines still gets nothing")
    func aChangedScopeOverContiguousLinesGetsNothing() {
        let hunks = [
            hunk(newStart: 1, newCount: 5, header: " func one()"),
            hunk(newStart: 40, newCount: 6, header: " func two()"),
        ]
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 34) == nil)
    }

    @Test("an unnamed hunk falls back to its coordinates")
    func anUnnamedHunkFallsBackToCoordinates() {
        let hunks = [hunk(newStart: 1, newCount: 5, header: ""), hunk(newStart: 40, newCount: 6, header: "")]
        #expect(DiffHunkHeading.text(for: hunks, at: 1, revealed: 0) == "@@ -40,6 +40,6 @@")
    }

    @Test("an index no hunk has gets nothing")
    func anIndexNoHunkHasGetsNothing() {
        #expect(DiffHunkHeading.text(for: [], at: 0, revealed: 0) == nil)
        #expect(DiffHunkHeading.text(for: [hunk(newStart: 40, newCount: 6)], at: 3, revealed: 0)
            == nil)
        #expect(DiffHunkHeading.text(for: [hunk(newStart: 40, newCount: 6)], at: -1, revealed: 0)
            == nil)
    }

    @Test("the band shows the scope git named")
    func theBandShowsTheScopeGitNamed() {
        #expect(DiffHunkHeading.text(of: hunk(newStart: 9, newCount: 2, header: " class A {"))
            == "class A {")
    }
}
