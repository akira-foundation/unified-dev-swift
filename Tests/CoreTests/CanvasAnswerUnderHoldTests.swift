import Foundation
import Testing
@testable import Core

@Suite("An answer read from a canvas under a hold says so", .scratchDirectory)
struct CanvasAnswerUnderHoldTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    @Test(arguments: [
        CanvasDiskWarning.refused("the file changed"), .backupFailed("disk full"), .saveOverRefused("disk full"),
        .fileTooLarge(70_000_000), .vanished,
    ])
    func everyHoldThatRefusesAnEditAlsoWarnsAReader(_ warning: CanvasDiskWarning) throws {
        let said = try #require(warning.heldAnswerWarning)
        #expect(said.contains("not what is on disk"))
        #expect(said.contains(warning.title))
    }

    @Test(arguments: [
        CanvasDiskWarning.saveFailed("x"), .tooLargeToSave(1), .tooLargeToKeepCopy(1),
        .reloaded(backups: ["a"], typingKeptIn: []), .savedOver(backups: ["a"], typingKeptIn: []),
        .copyKept(backups: ["a"], typingKeptIn: []), .draftRescued,
    ])
    func aNoticeWithNoHoldDoesNotWarnAReader(_ warning: CanvasDiskWarning) {
        #expect(warning.heldAnswerWarning == nil)
    }

    @Test func aReadAnswerCarriesTheWarning() async throws {
        let store = try makeTestStore("canvas-read-hold")
        let tool = CanvasReadTool { _, _ in
            .read(CanvasReadAnswer(document: CanvasDocument(), measuredTextSize: [:], warning: "held"))
        }
        let request = MCPRequest(id: .integer(1), method: CanvasReadToolName.read, params: .object(["path": .string("c.udcanvas")]))
        let result = await tool.call(request, as: identity, store: store)
        guard case .object(let fields)? = JSONValue.parse(Data(result.text.utf8)) else {
            Issue.record("not JSON: \(result.text)")
            return
        }
        #expect(fields["warning"] == .string("held"))
    }

    @Test func aReadAnswerWithNoHoldHasNoWarningField() async throws {
        let store = try makeTestStore("canvas-read-no-hold")
        let tool = CanvasReadTool { _, _ in .read(CanvasReadAnswer(document: CanvasDocument(), measuredTextSize: [:])) }
        let request = MCPRequest(id: .integer(1), method: CanvasReadToolName.read, params: .object(["path": .string("c.udcanvas")]))
        let result = await tool.call(request, as: identity, store: store)
        guard case .object(let fields)? = JSONValue.parse(Data(result.text.utf8)) else {
            Issue.record("not JSON: \(result.text)")
            return
        }
        #expect(fields["warning"] == nil)
    }

    @Test func aRenderAnswerCarriesTheWarning() async throws {
        let store = try makeTestStore("canvas-render-hold")
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let tool = CanvasRenderTool { _, _, _ in
            .rendered(CanvasRenderedFrame(png: png, size: CanvasSize(width: 10, height: 10), missingFonts: [], warning: "held by the tab"))
        }
        let request = MCPRequest(
            id: .integer(1), method: CanvasRenderToolName.render,
            params: .object(["path": .string("c.udcanvas"), "frame": .string("f")])
        )
        let result = await tool.call(request, as: identity, store: store)
        #expect(result.text.contains("held by the tab"))
        #expect(result.image?.data == png)
    }
}
