import Foundation
import Testing
@testable import Core

@Suite("How much of a canvas one read answers with", .scratchDirectory)
struct CanvasReadPageTests {
    private let identity = BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)

    private func rect() -> CanvasRect { CanvasRect(x: 0, y: 0, width: 10, height: 10) }

    private func text(_ id: String, _ words: String = "Hi") -> CanvasElement {
        CanvasElement(
            id: CanvasElementID(id), rect: rect(),
            kind: .text(CanvasText(runs: [CanvasTextRun(text: words, fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")]))
        )
    }

    private func read(_ document: CanvasDocument, offset: JSONValue? = nil, frameOffset: JSONValue? = nil, sizes: [CanvasElementID: CanvasSize] = [:]) async throws -> BridgeToolResult {
        let store = try makeTestStore("canvas-read-page")
        let tool = CanvasReadTool { _, _ in .read(CanvasReadAnswer(document: document, measuredTextSize: sizes)) }
        var params: [String: JSONValue] = ["path": .string("c.udcanvas")]
        if let offset { params["offset"] = offset }
        if let frameOffset { params["frameOffset"] = frameOffset }
        return await tool.call(MCPRequest(id: .integer(1), method: CanvasReadToolName.read, params: .object(params)), as: identity, store: store)
    }

    private func fields(_ result: BridgeToolResult) throws -> [String: JSONValue] {
        guard case .object(let fields)? = canvasAnswerJSON(result.text) else { throw CocoaError(.coderReadCorrupt) }
        return fields
    }

    private func elementIDs(_ fields: [String: JSONValue]) -> [String] {
        guard case .object(let body)? = fields["document"], case .array(let elements)? = body["elements"] else { return [] }
        return elements.compactMap { $0["id"]?.stringValue }
    }

    private func cutSentences(_ fields: [String: JSONValue]) -> String {
        guard case .array(let lines)? = fields["cut"] else { return "" }
        return lines.compactMap(\.stringValue).joined(separator: " ")
    }

    private var answerCeiling: Int { CanvasReadPage.characterLimit + 2_000 }

    @Test func aSmallCanvasIsAnsweredWholeWithNothingCut() async throws {
        let answer = try fields(await read(CanvasDocument(elements: [text("a")])))
        #expect(elementIDs(answer) == ["a"])
        #expect(answer["cut"] == nil)
        #expect(answer["nextOffset"] == nil)
    }

    @Test func aHugeFieldIsCutAndSaysSo() async throws {
        let huge = String(repeating: "x", count: 500_000)
        let result = try await read(CanvasDocument(elements: [text("a", huge)]))
        #expect(result.text.count < answerCeiling)
        #expect(!result.text.contains(String(repeating: "x", count: CanvasReadPage.fieldLimit + 1)))
        #expect(result.text.contains(String(repeating: "x", count: CanvasReadPage.fieldLimit)))
        #expect(cutSentences(try fields(result)).contains("1 long value"))
    }

    @Test func oneCharacterCarryingMillionsOfMarksIsCutByScalars() async throws {
        let marked = "e" + String(repeating: "\u{0301}", count: 5_000_000)
        let result = try await read(CanvasDocument(elements: [text("a", marked)]))

        #expect(result.text.unicodeScalars.count < answerCeiling)
        #expect(cutSentences(try fields(result)).contains("1 long value"))
    }

    @Test func aPageOfHeavilyMarkedTextStaysInBudget() async throws {
        let marked = "e" + String(repeating: "\u{0301}", count: 1_500)
        let elements = (0..<40).map { text("e\($0)", marked) }
        var seen: [String] = []
        var offset = 0
        var more = true
        while more {
            let result = try await read(CanvasDocument(elements: elements), offset: .integer(offset))
            #expect(result.text.unicodeScalars.count < answerCeiling)
            let answer = try fields(result)
            seen += elementIDs(answer)
            guard case .integer(let next)? = answer["nextOffset"] else {
                more = false
                continue
            }
            try #require(next > offset)
            offset = next
        }
        #expect(seen == elements.map(\.id.rawValue))
    }

    @Test func walkingThePagesReachesEveryElementOnce() async throws {
        let elements = (0..<500).map { text("e\($0)") }
        var seen: [String] = []
        var offset: JSONValue?
        var pages = 0
        repeat {
            let result = try await read(CanvasDocument(elements: elements), offset: offset)
            #expect(result.text.count < answerCeiling)
            let answer = try fields(result)
            seen += elementIDs(answer)
            offset = answer["nextOffset"]
            if offset != nil { #expect(cutSentences(answer).contains("offset")) }
            pages += 1
        } while offset != nil && pages < 100
        #expect(seen == elements.map(\.id.rawValue))
        #expect(pages > 1)
    }

    @Test func oneElementLargerThanAPageIsNamedAndTheWalkMovesOn() async throws {
        var large = text("large")
        let run = CanvasTextRun(text: "x", fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")
        large.kind = .text(CanvasText(runs: Array(repeating: run, count: 5_000)))
        let result = try await read(CanvasDocument(elements: [large, text("after")]))
        #expect(result.text.count < answerCeiling)
        let answer = try fields(result)
        #expect(elementIDs(answer) == ["large", "after"])
        #expect(cutSentences(answer).contains("large"))
    }

    private func tooLarge(_ id: String, frameID: String? = nil, runs: Int) -> CanvasElement {
        let run = CanvasTextRun(text: "x", fontName: "Helvetica", size: 12, weight: 0, colour: "#000000")
        return CanvasElement(
            id: CanvasElementID(id), frameID: frameID.map { CanvasFrameID($0) }, rect: rect(),
            kind: .text(CanvasText(runs: Array(repeating: run, count: runs)))
        )
    }

    @Test func aTooLargeElementWithAHugeFrameIDStillMovesTheWalkOn() async throws {
        let huge = String(repeating: "f", count: 40_000)
        let result = try await read(CanvasDocument(elements: [tooLarge("large", frameID: huge, runs: 5_000), text("after")]))

        #expect(result.text.count < answerCeiling)
        #expect(!result.text.contains(String(repeating: "f", count: CanvasReadPage.fieldLimit + 1)))
        let answer = try fields(result)
        #expect(elementIDs(answer) == ["large", "after"])
        #expect(answer["nextOffset"] == nil)
        #expect(!cutSentences(answer).contains("to -1"))
    }

    @Test func aTooLargeElementIsNamedByTheIDTheOtherToolsTake() async throws {
        let hostile = "a\u{1}b\"c"
        let result = try await read(CanvasDocument(elements: [tooLarge(hostile, runs: 5_000)]))
        let answer = try fields(result)

        #expect(elementIDs(answer) == [hostile])
        #expect(cutSentences(answer).contains(CanvasFileText.isFromFile))
    }

    @Test func aTooLargeElementWithAControlFrameIDBehindFullSharesStillMovesTheWalkOn() async throws {
        let frames = (0..<40).map { CanvasFrame(id: CanvasFrameID("frame-\(String(repeating: "x", count: 300))-\($0)"), name: "F", rect: rect()) }
        let comments = (0..<200).map {
            CanvasComment(id: CanvasCommentID("c\($0)"), anchor: CanvasPoint(x: 0, y: 0), text: "t", createdAt: Date(timeIntervalSince1970: 0))
        }
        let controls = String(repeating: "\u{1}", count: 2_000)
        let document = CanvasDocument(frames: frames, elements: [tooLarge(controls, frameID: controls, runs: 5_000), text("after")], comments: comments)

        let result = try await read(document, offset: .integer(0), frameOffset: .integer(0))
        let answer = try fields(result)

        #expect(result.text.unicodeScalars.count < answerCeiling)
        #expect(elementIDs(answer).count >= 1)
        #expect(answer["nextOffset"] != .integer(0))
        #expect(!cutSentences(answer).contains("to -1"))
    }

    @Test func everyAnswerOfAWalkOverTooLargeElementsAdvancesAndStaysInBudget() async throws {
        let longID = String(repeating: "e", count: 70)
        let elements = (0..<200).map { tooLarge("\(longID)\($0)", frameID: "f", runs: 320) }
        let document = CanvasDocument(elements: elements)
        var seen: [String] = []
        var offset = 0
        var more = true
        while more {
            let result = try await read(document, offset: .integer(offset))
            #expect(result.text.count < answerCeiling)
            let answer = try fields(result)
            seen += elementIDs(answer)
            guard case .integer(let next)? = answer["nextOffset"] else {
                more = false
                continue
            }
            try #require(next > offset)
            offset = next
        }
        #expect(seen == elements.map(\.id.rawValue))
    }

    private func frameIDs(_ fields: [String: JSONValue]) -> [String] {
        guard case .object(let body)? = fields["document"], case .array(let frames)? = body["frames"] else { return [] }
        return frames.compactMap { $0["id"]?.stringValue }
    }

    private func walkingFrames(of document: CanvasDocument) async throws -> [String] {
        var seen: [String] = []
        var offset = 0
        var more = true
        while more {
            let result = try await read(document, frameOffset: .integer(offset))
            #expect(result.text.count < answerCeiling)
            let answer = try fields(result)
            seen += frameIDs(answer)
            guard case .integer(let next)? = answer["nextFrameOffset"] else {
                more = false
                continue
            }
            #expect(cutSentences(answer).contains("frameOffset \(next)"))
            try #require(next > offset)
            offset = next
        }
        return seen
    }

    @Test func walkingTheFramesReachesTheLastEmptyFrameOfALongDeck() async throws {
        let frames = (0..<2_000).map { CanvasFrame(id: CanvasFrameID(UUID().uuidString), name: "Slide \($0)", rect: rect()) }

        let seen = try await walkingFrames(of: CanvasDocument(frames: frames))

        #expect(seen == frames.map(\.id.rawValue))
    }

    @Test func aFrameTooLargeForItsShareIsNamedAndTheWalkMovesOn() async throws {
        let unprintable = String(repeating: "\u{1}", count: 5_000)
        let large = CanvasFrame(id: CanvasFrameID("large"), name: unprintable, rect: rect(), fill: unprintable)
        let last = CanvasFrame(id: CanvasFrameID("last"), name: "Last", rect: rect())

        let seen = try await walkingFrames(of: CanvasDocument(frames: [large, last]))

        #expect(seen == ["large", "last"])
    }

    @Test func aTooLargeFrameIsNamedByTheIDTheOtherToolsTake() async throws {
        let unprintable = String(repeating: "\u{1}", count: 5_000)
        let hostile = "f\u{1}g\"h"
        let large = CanvasFrame(id: CanvasFrameID(hostile), name: unprintable, rect: rect(), fill: unprintable)

        let seen = try await walkingFrames(of: CanvasDocument(frames: [large]))

        #expect(seen == [hostile])
    }

    @Test func aTooLargeFrameWithAControlIDAndNameStillMovesTheWalkOn() async throws {
        let controls = String(repeating: "\u{1}", count: 2_000)
        let large = CanvasFrame(id: CanvasFrameID(controls), name: controls, rect: rect(), fill: controls)
        let last = CanvasFrame(id: CanvasFrameID("last"), name: "Last", rect: rect())

        let seen = try await walkingFrames(of: CanvasDocument(frames: [large, last]))

        #expect(seen.last == "last")
        #expect(seen.count == 2)
    }

    @Test func aWalkOfFramesDoesNotDisturbTheElementWalk() async throws {
        let frames = (0..<30).map { CanvasFrame(id: CanvasFrameID("frame-\(String(repeating: "x", count: 500))-\($0)"), name: "F", rect: rect()) }
        let answer = try fields(await read(CanvasDocument(frames: frames, elements: [text("a")]), frameOffset: .integer(5)))

        #expect(frameIDs(answer).first == frames[5].id.rawValue)
        #expect(elementIDs(answer) == ["a"])
        #expect(answer["nextFrameOffset"] != nil)
    }

    @Test func aFrameOffsetPastTheEndAnswersWithNoFrames() async throws {
        let answer = try fields(await read(CanvasDocument(frames: [CanvasFrame(name: "F", rect: rect())]), frameOffset: .integer(9)))

        #expect(frameIDs(answer).isEmpty)
        #expect(answer["nextFrameOffset"] == nil)
    }

    @Test(arguments: [JSONValue.integer(-1), .string("two"), .bool(true)])
    func aFrameOffsetThatIsNotACountIsRefused(offset: JSONValue) async throws {
        let result = try await read(CanvasDocument(), frameOffset: offset)

        #expect(result.isError)
        #expect(result.text.contains("frameOffset"))
    }

    @Test func commentsPastTheirShareAreCounted() async throws {
        let comments = (0..<2_000).map {
            CanvasComment(id: CanvasCommentID("c\($0)"), anchor: CanvasPoint(x: 0, y: 0), text: "t", createdAt: Date(timeIntervalSince1970: 0))
        }
        let result = try await read(CanvasDocument(comments: comments))
        #expect(result.text.count < answerCeiling)
        #expect(cutSentences(try fields(result)).contains("comments"))
    }

    @Test func measuredSizesCoverOnlyThePage() async throws {
        let elements = (0..<500).map { text("e\($0)") }
        let sizes = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, CanvasSize(width: 1, height: 1)) })
        let answer = try fields(await read(CanvasDocument(elements: elements), sizes: sizes))
        guard case .object(let measured)? = answer["measuredTextSize"] else {
            Issue.record("no measuredTextSize")
            return
        }
        #expect(Set(measured.keys) == Set(elementIDs(answer)))
    }

    @Test(arguments: [JSONValue.integer(-1), .string("two"), .bool(true)])
    func anOffsetThatIsNotACountIsRefused(offset: JSONValue) async throws {
        let result = try await read(CanvasDocument(elements: [text("a")]), offset: offset)
        #expect(result.isError)
        #expect(result.text.contains("offset"))
    }

    @Test func anOffsetPastTheEndAnswersWithNoElements() async throws {
        let answer = try fields(await read(CanvasDocument(elements: [text("a")]), offset: .integer(9)))
        #expect(elementIDs(answer).isEmpty)
        #expect(answer["nextOffset"] == nil)
    }
}
