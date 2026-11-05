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

    private func read(_ document: CanvasDocument, offset: JSONValue? = nil, sizes: [CanvasElementID: CanvasSize] = [:]) async throws -> BridgeToolResult {
        let store = try makeTestStore("canvas-read-page")
        let tool = CanvasReadTool { _, _ in .read(CanvasReadAnswer(document: document, measuredTextSize: sizes)) }
        var params: [String: JSONValue] = ["path": .string("c.udcanvas")]
        if let offset { params["offset"] = offset }
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

    @Test func framesAndCommentsPastTheirShareAreCounted() async throws {
        let frames = (0..<2_000).map { CanvasFrame(id: CanvasFrameID("f\($0)"), name: "F", rect: rect()) }
        let comments = (0..<2_000).map {
            CanvasComment(id: CanvasCommentID("c\($0)"), anchor: CanvasPoint(x: 0, y: 0), text: "t", createdAt: Date(timeIntervalSince1970: 0))
        }
        let result = try await read(CanvasDocument(frames: frames, comments: comments))
        #expect(result.text.count < answerCeiling)
        let said = cutSentences(try fields(result))
        #expect(said.contains("frames"))
        #expect(said.contains("comments"))
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
