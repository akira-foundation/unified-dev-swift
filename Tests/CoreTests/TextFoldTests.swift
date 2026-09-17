import Testing
@testable import Core

@Suite("What the fold under a block of output says")
struct TextFoldTests {
    @Test("it folds back, which is the whole point of it")
    func bothDirections() {
        #expect(TextFold.title(isExpanded: false) == "Show all")
        #expect(TextFold.title(isExpanded: true) == "Show less")
    }

    @Test("a caller that has counted the lines says so, and one that has not is not made to")
    func lineCount() {
        #expect(TextFold.title(isExpanded: false, lines: 812) == "Show all 812 lines")
        #expect(TextFold.title(isExpanded: false, lines: nil) == "Show all")
    }

    @Test("one line is a line")
    func singular() {
        #expect(TextFold.title(isExpanded: false, lines: 1) == "Show all 1 line")
    }

    @Test("the way back never carries the count")
    func expandedIgnoresCount() {
        #expect(TextFold.title(isExpanded: true, lines: 812) == "Show less")
    }
}
