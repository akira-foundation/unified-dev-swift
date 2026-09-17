import Testing
@testable import Core

@Suite("Cycling the centre tabs")
struct TabCycleTests {
    private let tabs = ["chat", "diff", "terminal"]

    @Test("forwards and backwards move one")
    func movesOne() {
        #expect(TabCycle.next(from: "chat", in: tabs, offset: 1) == "diff")
        #expect(TabCycle.next(from: "diff", in: tabs, offset: -1) == "chat")
    }

    @Test("both ends wrap")
    func bothEndsWrap() {
        #expect(TabCycle.next(from: "terminal", in: tabs, offset: 1) == "chat")
        #expect(TabCycle.next(from: "chat", in: tabs, offset: -1) == "terminal")
    }

    @Test("an offset larger than the strip still lands inside it")
    func largeOffsetsStayInBounds() {
        #expect(TabCycle.next(from: "chat", in: tabs, offset: 4) == "diff")
        #expect(TabCycle.next(from: "chat", in: tabs, offset: -4) == "terminal")
        #expect(TabCycle.next(from: "chat", in: tabs, offset: -100) != nil)
    }

    @Test("a strip with nothing to move to answers nothing")
    func nothingToMoveTo() {
        #expect(TabCycle.next(from: "chat", in: ["chat"], offset: 1) == nil)
        #expect(TabCycle.next(from: nil, in: [String](), offset: 1) == nil)
        #expect(TabCycle.next(from: "chat", in: tabs, offset: 3) == nil)
    }

    @Test("a tab that is gone lands on the first")
    func aClosedTabLandsSomewhere() {
        #expect(TabCycle.next(from: "gone", in: tabs, offset: 1) == "chat")
        #expect(TabCycle.next(from: nil, in: tabs, offset: -1) == "chat")
    }

    @Test("a number reaches its tab, and nine reaches the last one")
    func numbersReachTabs() {
        let strip = (1...12).map { "tab\($0)" }
        #expect(TabCycle.tab(at: 1, in: strip) == "tab1")
        #expect(TabCycle.tab(at: 8, in: strip) == "tab8")
        #expect(TabCycle.tab(at: 9, in: strip) == "tab12")
        #expect(TabCycle.tab(at: 3, in: tabs) == "terminal")
        #expect(TabCycle.tab(at: 9, in: tabs) == "terminal")
    }

    @Test("a number past the end of a short strip reaches nothing")
    func numbersPastTheEnd() {
        #expect(TabCycle.tab(at: 4, in: tabs) == nil)
        #expect(TabCycle.tab(at: 1, in: [String]()) == nil)
        #expect(TabCycle.tab(at: 0, in: tabs) == nil)
        #expect(TabCycle.tab(at: 10, in: tabs) == nil)
    }

    @Test("the menu numbers the first eight and the last")
    func numberingForTheMenu() {
        let numbered = TabCycle.numbered((1...12).map { "tab\($0)" })
        #expect(numbered.count == 12)
        #expect(numbered.map(\.ordinal) == [1, 2, 3, 4, 5, 6, 7, 8, nil, nil, nil, 9])

        #expect(TabCycle.numbered(tabs).map(\.ordinal) == [1, 2, 3])
        #expect(TabCycle.numbered([String]()).isEmpty)
    }

    @Test("a strip of nine has no unreachable tab")
    func nineExactly() {
        #expect(TabCycle.numbered((1...9).map { "tab\($0)" }).map(\.ordinal)
            == [1, 2, 3, 4, 5, 6, 7, 8, 9])
    }
}
