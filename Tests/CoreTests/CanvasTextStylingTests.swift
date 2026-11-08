import Foundation
import Testing
@testable import Core

@Suite("CanvasTextStyling")
struct CanvasTextStylingTests {
    private func run(_ text: String, colour: String = "#000000", size: Double = 12, weight: Double = 0) -> CanvasTextRun {
        CanvasTextRun(text: text, fontName: "Helvetica", size: size, weight: weight, colour: colour)
    }

    private func texts(_ text: CanvasText) -> [String] { text.runs.map(\.text) }

    @Test func stylingSplitsRuns() {
        let source = CanvasText(runs: [run("Hello world")])
        let result = CanvasTextStyling.applying(CanvasRunChange(colour: "#FF0000"), range: 3..<8, to: source)
        #expect(texts(result) == ["Hel", "lo wo", "rld"])
        #expect(result.runs.map(\.colour) == ["#000000", "#FF0000", "#000000"])
    }

    @Test func stylingMergesEqualNeighbours() {
        let source = CanvasText(runs: [run("ab"), run("cd", colour: "#FF0000"), run("ef")])
        let result = CanvasTextStyling.applying(CanvasRunChange(colour: "#000000"), range: 2..<4, to: source)
        #expect(texts(result) == ["abcdef"])
    }

    @Test func anEmptySelectionChangesNothing() {
        let source = CanvasText(runs: [run("ab"), run("cd", colour: "#FF0000")])
        #expect(CanvasTextStyling.applying(CanvasRunChange(size: 40), range: 2..<2, to: source) == source)
    }

    @Test func aRangeOutsideTheTextIsClamped() {
        let source = CanvasText(runs: [run("abc")])
        let result = CanvasTextStyling.applying(CanvasRunChange(size: 40), range: 1..<99, to: source)
        #expect(texts(result) == ["a", "bc"])
        #expect(result.runs.map(\.size) == [12, 40])
    }

    @Test func combinedCharactersAreNotSplit() {
        let source = CanvasText(runs: [run("e\u{301}x")])
        let result = CanvasTextStyling.applying(CanvasRunChange(weight: 0.4), range: 0..<1, to: source)
        #expect(texts(result) == ["e\u{301}", "x"])
        #expect(result.runs.map(\.weight) == [0.4, 0])
    }

    @Test func rangesCoverRunsAcrossBoundaries() {
        let source = CanvasText(runs: [run("ab"), run("cd", colour: "#FF0000")])
        let result = CanvasTextStyling.applying(CanvasRunChange(size: 30), range: 1..<3, to: source)
        #expect(texts(result) == ["a", "b", "c", "d"])
        #expect(result.runs.map(\.size) == [12, 30, 30, 12])
        #expect(result.runs.map(\.colour) == ["#000000", "#000000", "#FF0000", "#FF0000"])
    }

    @Test func utf16SelectionsBecomeCharacterRanges() {
        let text = "a\u{1F600}e\u{301}b"
        #expect(CanvasTextStyling.characterRange(of: NSRange(location: 1, length: 2), in: text) == 1..<2)
        #expect(CanvasTextStyling.characterRange(of: NSRange(location: 3, length: 2), in: text) == 2..<3)
    }

    @Test func emptyRunsAreDroppedButAnEmptyTextKeepsItsStyle() {
        let result = CanvasTextStyling.normalised([run("", size: 30), run("a"), run("")])
        #expect(texts(result) == ["a"])
        let empty = CanvasTextStyling.normalised([run("", size: 30)])
        #expect(empty.runs.map(\.size) == [30])
        #expect(empty.runs.map(\.text) == [""])
    }
}

@Suite("CanvasTextStylingDelta")
struct CanvasTextStylingDeltaTests {
    private let id = CanvasElementID("t")

    private func document() -> CanvasDocument {
        CanvasDocument(elements: [CanvasElement(
            id: id, rect: CanvasRect(x: 0, y: 0, width: 100, height: 40),
            kind: .text(CanvasText(runs: [CanvasTextRun(text: "Hi", fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")]))
        )])
    }

    @Test func aDelayedColourKeepsALaterSizeChange() {
        var session = CanvasDocumentSession(document: document())
        _ = session.apply(CanvasTextStyling.operations(applying: CanvasRunChange(size: 40), to: [id], in: session.document), by: .owner)
        _ = session.apply(CanvasTextStyling.operations(applying: CanvasRunChange(colour: "#FF0000"), to: [id], in: session.document), by: .owner)
        let run = session.document.elements.first?.text?.runs.first
        #expect(run?.size == 40)
        #expect(run?.colour == "#FF0000")
    }

    @Test func elementsWithoutTextAreSkipped() {
        let shape = CanvasElement(id: CanvasElementID("s"), rect: CanvasRect(x: 0, y: 0, width: 1, height: 1), kind: .shape(CanvasShape(kind: .rectangle)))
        let operations = CanvasTextStyling.operations(applying: CanvasRunChange(size: 9), to: [shape.id], in: CanvasDocument(elements: [shape]))
        #expect(operations.isEmpty)
    }
}
