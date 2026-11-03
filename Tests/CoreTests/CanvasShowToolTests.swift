import Foundation
import Testing
@testable import Core

@Suite("Showing a workspace file in the canvas", .scratchDirectory)
struct CanvasShowToolTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func request(_ fields: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: CanvasShowToolName.show, params: .object(fields))
    }

    @Test("the tool hands a trimmed path, title, focus and caller to its own workspace")
    func call() async throws {
        let store = try makeTestStore("canvas-show")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(
            request([
                "path": .string(" docs/a.html "),
                "title": .string(" Report "),
                "focus": .bool(false),
            ]),
            as: identity,
            store: store
        )

        #expect(!result.isError)
        #expect(
            await recorder.values == [
                Value(
                    order: CanvasShowOrder(
                        path: "docs/a.html", title: "Report", focus: false, caller: SessionID("s")
                    ),
                    workspaceID: WorkspaceID("w")
                ),
            ]
        )
    }

    @Test("focus defaults to true and an empty title is none")
    func defaults() async throws {
        let store = try makeTestStore("canvas-show-defaults")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        _ = await tool.call(
            request(["path": .string("a.md"), "title": .string("  ")]), as: identity, store: store
        )

        let orders = await recorder.values.map(\.order)
        #expect(orders == [CanvasShowOrder(path: "a.md", title: nil, focus: true, caller: SessionID("s"))])
    }

    @Test("an empty path is refused without calling the app")
    func emptyPath() async throws {
        let store = try makeTestStore("canvas-show-empty")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(request(["path": .string("  ")]), as: identity, store: store)

        #expect(result.isError)
        #expect(await recorder.values.isEmpty)
    }

    @Test("a caller with no workspace is refused")
    func noWorkspace() async throws {
        let store = try makeTestStore("canvas-show-scope")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(
            request(["path": .string("a.md")]),
            as: BridgeIdentity(ownerSession: SessionID("s")),
            store: store
        )

        #expect(result.isError)
        #expect(await recorder.values.isEmpty)
    }

    @Test("a focus that is not a boolean is refused without calling the app")
    func badFocus() async throws {
        let store = try makeTestStore("canvas-show-focus")
        let recorder = Recorder()
        let tool = CanvasShowTool { order, workspaceID in
            await recorder.record(order, workspaceID: workspaceID)
            return .shown("shown")
        }
        let result = await tool.call(
            request(["path": .string("a.md"), "focus": .string("no")]), as: identity, store: store
        )

        #expect(result.isError)
        #expect(await recorder.values.isEmpty)
    }

    @Test("a refusal from the app is an error result")
    func refusal() async throws {
        let store = try makeTestStore("canvas-show-refusal")
        let tool = CanvasShowTool { _, _ in .refused("x") }
        let result = await tool.call(request(["path": .string("a.md")]), as: identity, store: store)

        #expect(result.isError)
        #expect(result.text == "x")
    }

    @Test("canvas_show approves itself")
    func approval() {
        #expect(
            BridgeToolApproval.isSelfApproved(
                toolName: BridgeToolApproval.toolPrefix + CanvasShowToolName.show
            )
        )
    }

    @Test("every format the description names is one the canvas accepts, and every accepted one is named")
    func description() {
        let text = CanvasShowTool { _, _ in .refused("x") }.tool.description
        let formats: [String: String] = [
            "HTML": "html", "Markdown": "md", "SVG": "svg", "PNG": "png", "JPEG": "jpeg",
            "GIF": "gif", "WebP": "webp", "PDF": "pdf", "TIFF": "tiff", "HEIC": "heic",
            "BMP": "bmp", "AVIF": "avif", "ICO": "ico", "JSON": "json", "CSV": "csv",
        ]
        let named = formats.filter { text.contains($0.key) }

        for (word, ext) in named {
            #expect(CanvasFile.extensions.contains(ext), "the description names \(word)")
        }
        for (word, ext) in formats where CanvasFile.extensions.contains(ext) {
            #expect(named[word] != nil, "the description leaves out \(word)")
        }
    }

    private struct Value: Sendable, Equatable {
        var order: CanvasShowOrder
        var workspaceID: WorkspaceID
    }

    private actor Recorder {
        var values: [Value] = []
        func record(_ order: CanvasShowOrder, workspaceID: WorkspaceID) {
            values.append(Value(order: order, workspaceID: workspaceID))
        }
    }
}
