import Testing
@testable import Core

@Suite("Folding a reviewed file")
struct ReviewCollapseTests {
    @Test("A tick folds the file it arrived on")
    func ticking() {
        let folded = ReviewCollapse.collapsed([], viewed: ["a.swift"], wasViewed: [])
        #expect(folded == ["a.swift"])
    }

    @Test("Taking a tick off opens the file again")
    func unticking() {
        let folded = ReviewCollapse.collapsed(["a.swift"], viewed: [], wasViewed: ["a.swift"])
        #expect(folded.isEmpty)
    }

    @Test("A tick leaves every other file where it was")
    func neighbours() {
        let folded = ReviewCollapse.collapsed(
            ["b.swift"], viewed: ["a.swift", "c.swift"], wasViewed: ["c.swift"]
        )
        #expect(folded == ["a.swift", "b.swift"])
    }

    @Test("An unchanged set moves nothing, so a file opened again by hand stays open")
    func reopenedByHand() {
        let ticks: Set<String> = ["a.swift"]
        var folded = ReviewCollapse.collapsed([], viewed: ticks, wasViewed: [])
        #expect(folded == ["a.swift"])

        folded.remove("a.swift")
        for _ in 0..<5 {
            folded = ReviewCollapse.collapsed(folded, viewed: ticks, wasViewed: ticks)
        }
        #expect(folded.isEmpty)
    }

    @Test("A file folded by hand stays folded when the tick comes off the file beside it")
    func foldedByHand() {
        let folded = ReviewCollapse.collapsed(["a.swift"], viewed: [], wasViewed: ["b.swift"])
        #expect(folded == ["a.swift"])
    }

    @Test("Marks arriving from the store fold every file they are on")
    func firstRead() {
        let folded = ReviewCollapse.collapsed([], viewed: ["a.swift", "b.swift"], wasViewed: [])
        #expect(folded == ["a.swift", "b.swift"])
    }

    @Test("Reopening the review folds what is marked and leaves the rest open")
    func reopening() {
        let marks: Set<String> = ["a.swift", "c.swift"]
        let folded = ReviewCollapse.collapsed([], viewed: marks, wasViewed: [])
        #expect(folded == marks)

        let again = ReviewCollapse.collapsed(folded, viewed: marks, wasViewed: marks)
        #expect(again == marks)
    }
}
