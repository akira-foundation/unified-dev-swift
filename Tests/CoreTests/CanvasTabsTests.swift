import Foundation
import Testing
@testable import Core

@Suite("Canvas tabs")
struct CanvasTabsTests {
    private struct Tab: CanvasTabValue, Codable, Equatable {
        var id: String
        var kind: CenterTabKind
        var title: String
        var path: String = ""
        var isNamed: Bool = false
    }

    private let terminal = Tab(id: "t", kind: .terminal, title: "Terminal")
    private let browser = Tab(id: "b", kind: .browser, title: "Browser")
    private let canvas = Tab(id: "c", kind: .canvas, title: "Canvas", path: "docs/a.html")

    private func fresh() -> Tab { Tab(id: "new", kind: .canvas, title: "Canvas") }

    @Test("a workspace with no canvas gets one, at the end")
    func createsWhenNone() {
        let shown = CanvasTabs.show(path: "docs/b.md", title: nil, in: [terminal, browser], making: fresh)

        #expect(shown.tabs.count == 3)
        #expect(shown.index == 2)
        #expect(shown.tabs[2].id == "new")
        #expect(shown.tabs[2].path == "docs/b.md")
    }

    @Test("a workspace with a canvas swaps its file, keeping its id and position")
    func swapsInPlace() {
        let shown = CanvasTabs.show(path: "docs/b.md", title: nil, in: [terminal, canvas, browser], making: fresh)

        #expect(shown.index == 1)
        #expect(shown.tabs.map(\.id) == ["t", "c", "b"])
        #expect(shown.tabs[1].path == "docs/b.md")
    }

    @Test("showing a file leaves every other tab exactly as it was")
    func othersUntouched() {
        let shown = CanvasTabs.show(path: "docs/b.md", title: "Report", in: [terminal, canvas, browser], making: fresh)

        #expect(shown.tabs[0] == terminal)
        #expect(shown.tabs[2] == browser)
    }

    @Test("there is never a second canvas, even when the list already holds two")
    func neverASecond() {
        var other = canvas
        other.id = "c2"
        let once = CanvasTabs.show(path: "x.md", title: nil, in: [canvas], making: fresh)
        let twice = CanvasTabs.show(path: "x.md", title: nil, in: [canvas, other], making: fresh)

        #expect(once.tabs.filter { $0.kind == .canvas }.count == 1)
        #expect(twice.tabs.count == 2)
        #expect(twice.index == 0)
        #expect(twice.tabs[1] == other)
    }

    @Test("a title names the canvas, and a swap without one gives the name back to the file")
    func naming() {
        let named = CanvasTabs.show(path: "a.md", title: "  Report  ", in: [canvas], making: fresh)
        let swapped = CanvasTabs.show(path: "b.md", title: nil, in: named.tabs, making: fresh)
        let blank = CanvasTabs.show(path: "c.md", title: "  ", in: named.tabs, making: fresh)

        #expect(named.tabs[0].title == "Report")
        #expect(named.tabs[0].isNamed)
        #expect(!swapped.tabs[0].isNamed)
        #expect(!blank.tabs[0].isNamed)
    }

    @Test("a list with a canvas splits into the list without it and the canvas with its place")
    func splits() {
        let split = CanvasTabs.split([terminal, canvas, browser])

        #expect(split.list == [terminal, browser])
        #expect(split.canvas?.tab == canvas)
        #expect(split.canvas?.index == 1)
    }

    @Test("a list without a canvas splits into itself and nothing")
    func splitsWithoutCanvas() {
        let split = CanvasTabs.split([terminal, browser])

        #expect(split.list == [terminal, browser])
        #expect(split.canvas == nil)
    }

    @Test("merging puts the canvas back where it was, or at the end when the list has shrunk")
    func merges() {
        let split = CanvasTabs.split([terminal, canvas, browser])

        #expect(CanvasTabs.merge(split.list, canvas: split.canvas) == [terminal, canvas, browser])
        #expect(CanvasTabs.merge([], canvas: split.canvas) == [canvas])
        #expect(CanvasTabs.merge([browser], canvas: StoredCanvasTab(index: 9, tab: canvas)) == [browser, canvas])
        #expect(CanvasTabs.merge([browser], canvas: StoredCanvasTab(index: -3, tab: canvas)) == [canvas, browser])
    }

    @Test("with no canvas stored the list comes back untouched")
    func absentKey() {
        #expect(CanvasTabs.merge([terminal, browser], canvas: nil) == [terminal, browser])
    }

    @Test("an old list that still holds its canvas keeps it, and the next split moves it out")
    func migrates() {
        let old = [terminal, canvas, browser]
        let restored = CanvasTabs.merge(old, canvas: nil)
        let split = CanvasTabs.split(restored)

        #expect(restored == old)
        #expect(split.list == [terminal, browser])
        #expect(split.canvas?.tab == canvas)
    }

    @Test("a stored canvas replaces any canvas a list still carries, so there is only one")
    func storedWins() {
        var stale = canvas
        stale.id = "stale"
        let merged = CanvasTabs.merge([stale, terminal], canvas: StoredCanvasTab(index: 1, tab: canvas))

        #expect(merged == [terminal, canvas])
    }

    @Test("the list key a published build reads strictly never carries a canvas")
    func roundTrip() throws {
        let split = CanvasTabs.split([terminal, canvas])
        let list = try JSONEncoder().encode(split.list)
        let stored = try JSONEncoder().encode(split.canvas)

        let strict = try JSONDecoder().decode([Tab].self, from: list)
        let canvasBack = try JSONDecoder().decode(StoredCanvasTab<Tab>.self, from: stored)

        #expect(!strict.contains { $0.kind == .canvas })
        #expect(CanvasTabs.merge(strict, canvas: canvasBack) == [terminal, canvas])
        #expect(CanvasTabs.storageKey(WorkspaceID("w")) == TabDefaults.tabListKey(WorkspaceID("w")) + ".canvas")
    }
}
