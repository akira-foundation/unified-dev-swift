import Foundation
import Testing
@testable import Core

@Suite("Naming the pictures of an export")
struct CanvasExportNamesTests {
    private func frame(_ name: String, x: Double = 0, y: Double = 0, id: String? = nil) -> CanvasFrame {
        CanvasFrame(
            id: CanvasFrameID(id ?? name + "-\(x)-\(y)"), name: name, rect: CanvasRect(x: x, y: y, width: 1_080, height: 1_080)
        )
    }

    private func names(_ frames: [CanvasFrame], document: String = "deck") -> [String] {
        let files = CanvasExportNames.files(for: frames, document: document)
        return CanvasExportNames.slideOrder(frames).compactMap { files[$0.id] }
    }

    @Test func slideOrderIsLeftToRight() {
        let frames = [frame("c", x: 2_200), frame("a", x: 0), frame("b", x: 1_100)]
        #expect(CanvasExportNames.slideOrder(frames).map(\.name) == ["a", "b", "c"])
    }

    @Test func aTieOnTheLeftEdgeIsDecidedFromTopToBottom() {
        let frames = [frame("low", x: 0, y: 1_200), frame("high", x: 0, y: 0), frame("right", x: 50, y: -400)]
        #expect(CanvasExportNames.slideOrder(frames).map(\.name) == ["high", "low", "right"])
    }

    @Test func aFullTieKeepsTheOrderInTheFile() {
        let frames = [frame("first", id: "1"), frame("second", id: "2")]
        #expect(CanvasExportNames.slideOrder(frames).map(\.name) == ["first", "second"])
    }

    @Test func namesAreNumberedAndSafe() {
        let frames = [frame("Intro / Cover", x: 0), frame("Café: Olá", x: 1_100), frame("Same", x: 2_200), frame("Same", x: 3_300)]
        #expect(names(frames) == ["01-intro-cover.png", "02-café-olá.png", "03-same.png", "04-same.png"])
    }

    @Test func twoFramesWithTheSameNameDoNotCollide() {
        let frames = [frame("Same", x: 0), frame("Same", x: 1), frame("same", x: 2), frame("SAME", x: 3)]
        let produced = names(frames)
        #expect(Set(produced.map { $0.lowercased() }).count == 4)
    }

    @Test func namesDifferingOnlyByUnicodeNormalisationDoNotCollideOnACaseInsensitiveVolume() {
        let composed = "Caf\u{E9}"
        let decomposed = "Cafe\u{301}"
        let produced = names([frame(composed, x: 0), frame(decomposed, x: 1)])
        #expect(produced.count == 2)
        #expect(Set(produced.map { $0.precomposedStringWithCanonicalMapping.lowercased() }).count == 2)
        #expect(produced[0] == produced[1].replacingOccurrences(of: "02-", with: "01-"))
        #expect(produced.allSatisfy { $0 == $0.precomposedStringWithCanonicalMapping })
    }

    @Test(arguments: ["..", "../../etc/passwd", "/etc/passwd", ".hidden", "...", "a/../../b", "a\\b", "c:\\windows"])
    func aHostileNameCannotLeaveTheDirectory(name: String) {
        let produced = names([frame(name)])
        let file = produced[0]
        #expect(!file.contains("/") && !file.contains("\\") && !file.contains(".."))
        #expect(!file.hasPrefix("."))
        #expect(file.hasSuffix(".png") && file.filter { $0 == "." }.count == 1)
        #expect(CanvasExportNames.isExportedFile(file))
    }

    @Test func controlCharactersAndInvisibleFormattingAreDropped() {
        let produced = names([frame("a\u{0}b\nc\u{7}d\u{202E}e\u{200B}f\te")])
        #expect(produced == ["01-a-b-c-d-e-f-e.png"])
    }

    @Test(arguments: ["CON", "NUL", "aux", "COM1", "LPT9", "."])
    func aReservedNameIsStillAFileNameBecauseOfItsNumber(name: String) {
        let file = names([frame(name)])[0]
        #expect(file.hasPrefix("01-"))
        #expect(CanvasExportNames.isExportedFile(file))
    }

    @Test func aVeryLongNameIsCutWithinTheLimitOnACharacterBoundary() {
        let long = String(repeating: "\u{E9}", count: 400)
        let file = names([frame(long)])[0]
        let slug = String(file.dropFirst(3).dropLast(4))
        #expect(slug.utf8.count <= CanvasExportNames.longestSlugBytes)
        #expect(slug.allSatisfy { $0 == "\u{E9}" } && !slug.isEmpty)
        #expect(file.utf8.count < 255)
    }

    @Test func aNameWithNothingUsableFallsBackToTheDocumentName() {
        #expect(names([frame("///")], document: "My Deck") == ["01-my-deck.png"])
        #expect(names([frame("")], document: "...") == ["01-frame.png"])
    }

    @Test func theNumberWidthGrowsPastNinetyNineSlides() {
        let frames = (0..<100).map { frame("s", x: Double($0)) }
        let produced = names(frames)
        #expect(produced.first == "001-s.png")
        #expect(produced.last == "100-s.png")
    }

    @Test func theDirectoryNameComesFromTheDocumentFileName() {
        #expect(CanvasExportNames.directoryName(forDocumentAt: "/w/a/Spring Launch.udcanvas") == "spring-launch.export")
        #expect(CanvasExportNames.directoryName(forDocumentAt: "/w/a/....udcanvas") == "canvas.export")
        #expect(CanvasExportNames.directoryName(forDocumentAt: "/w/a/.udcanvas") == "udcanvas.export")
        #expect(CanvasExportNames.directoryName(forDocumentAt: "/w/a/???.udcanvas") == "canvas.export")
        let long = String(repeating: "x", count: 300) + ".udcanvas"
        #expect(CanvasExportNames.directoryName(forDocumentAt: "/w/\(long)").utf8.count < 255)
    }

    @Test func onlyTheNumberedPicturePatternIsOurs() {
        #expect(CanvasExportNames.isExportedFile("01-cover.png"))
        #expect(CanvasExportNames.isExportedFile("100-x.png"))
        for other in ["cover.png", "1-cover.png", "01cover.png", "01-cover.jpg", "01-cover.png.bak", "notes.md", ".01-a.png", "01-.txt", "ab-01.png"] {
            #expect(!CanvasExportNames.isExportedFile(other), "\(other)")
        }
    }
}
