import Testing
@testable import Core

@Suite("How wide the settings form reads")
struct SettingsColumnTests {
    @Test("a pane wider than the column keeps its form to the column, centred")
    func aWidePaneCentresTheColumn() {
        #expect(SettingsColumn.sideMargin(in: 1_280, column: SettingsColumn.width) == 300)
        #expect(SettingsColumn.sideMargin(in: 681, column: SettingsColumn.width) == 0.5)
    }

    @Test("a pane no wider than the column gives the form all of it")
    func aNarrowPaneAddsNoMargin() {
        #expect(SettingsColumn.sideMargin(in: 680, column: SettingsColumn.width) == 0)
        #expect(SettingsColumn.sideMargin(in: 480, column: SettingsColumn.width) == 0)
    }

    @Test("the margin is worked out from the column it is given")
    func theMarginFollowsTheColumn() {
        #expect(SettingsColumn.sideMargin(in: 1_000, column: 400) == 300)
    }

    @Test("a form with no column of its own, in a window of its own, is left alone")
    func noColumnNoMargin() {
        #expect(SettingsColumn.sideMargin(in: 1_280, column: nil) == 0)
    }
}
