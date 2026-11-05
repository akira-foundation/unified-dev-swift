import Foundation
import Testing
@testable import Core

@Suite("Rendering a canvas frame", .scratchDirectory)
struct CanvasRenderToolTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func request(_ fields: [String: JSONValue]) -> MCPRequest {
        MCPRequest(id: .integer(1), method: CanvasRenderToolName.render, params: .object(fields))
    }

    private let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    @Test("a frame comes back as a picture, with the path and frame the agent named")
    func renderReturnsAPicture() async throws {
        let store = try makeTestStore("canvas-render")
        let png = png
        let tool = CanvasRenderTool { path, frame, workspaceID in
            #expect(path == "c.udcanvas")
            #expect(frame == CanvasFrameID("f"))
            #expect(workspaceID == WorkspaceID("w"))
            return .rendered(CanvasRenderedFrame(png: png, size: CanvasSize(width: 300, height: 200), missingFonts: []))
        }
        let result = await tool.call(
            request(["path": .string(" c.udcanvas "), "frame": .string("f")]), as: identity, store: store
        )

        #expect(!result.isError)
        #expect(result.image?.data == png)
        #expect(result.text.contains("300"))
        #expect(result.text.contains("200"))
    }

    @Test("a frame that is not there is refused with the app's reason")
    func renderUnknownFrameIsRefused() async throws {
        let store = try makeTestStore("canvas-render-unknown")
        let tool = CanvasRenderTool { _, _, _ in .refused("There is no frame 'x' in this canvas.") }
        let result = await tool.call(
            request(["path": .string("c.udcanvas"), "frame": .string("x")]), as: identity, store: store
        )

        #expect(result.isError)
        #expect(result.text.contains("no frame 'x'"))
        #expect(result.image == nil)
    }

    @Test("a missing path or frame is refused without calling the app")
    func argumentsAreChecked() async throws {
        let store = try makeTestStore("canvas-render-arguments")
        let tool = CanvasRenderTool { _, _, _ in
            Issue.record("the app must not be called")
            return .refused("x")
        }
        let noFrame = await tool.call(request(["path": .string("c.udcanvas")]), as: identity, store: store)
        let noPath = await tool.call(request(["frame": .string("f")]), as: identity, store: store)

        #expect(noFrame.isError && noPath.isError)
    }

    @Test("missing fonts are named in the text")
    func missingFontsAreNamed() async throws {
        let store = try makeTestStore("canvas-render-fonts")
        let png = png
        let tool = CanvasRenderTool { _, _, _ in
            .rendered(CanvasRenderedFrame(png: png, size: CanvasSize(width: 10, height: 10), missingFonts: ["Zapfino Two", "Nope"]))
        }
        let result = await tool.call(
            request(["path": .string("c.udcanvas"), "frame": .string("f")]), as: identity, store: store
        )

        #expect(result.text.contains("Zapfino Two"))
        #expect(result.text.contains("Nope"))
    }

    @Test("a picture too large to send is refused with a way forward")
    func oversizedPictureIsRefused() async throws {
        let store = try makeTestStore("canvas-render-large")
        let big = Data(count: BridgeToolImage.maximumBytes + 1)
        let tool = CanvasRenderTool { _, _, _ in
            .rendered(CanvasRenderedFrame(png: big, size: CanvasSize(width: 10, height: 10), missingFonts: []))
        }
        let result = await tool.call(
            request(["path": .string("c.udcanvas"), "frame": .string("f")]), as: identity, store: store
        )

        #expect(result.isError)
        #expect(result.image == nil)
    }

    @Test("a frame up to 8192 points is rendered at 1:1 and a larger one is refused")
    func sizeLimits() {
        #expect(CanvasRenderPlan(frameSize: CanvasSize(width: 8_192, height: 8_192)) != nil)
        #expect(CanvasRenderPlan(frameSize: CanvasSize(width: 8_193, height: 10)) == nil)
        #expect(CanvasRenderPlan(frameSize: CanvasSize(width: 0, height: 10)) == nil)
        #expect(CanvasRenderPlan(frameSize: CanvasSize(width: 1_000, height: 2_048))?.scale == 1)
        #expect(CanvasRenderPlan(frameSize: CanvasSize(width: 1_000, height: 2_048))?.isReduced == false)
    }

    @Test("the longest side is capped at 2048 pixels and the text says so")
    func longestSideIsCapped() throws {
        let plan = try #require(CanvasRenderPlan(frameSize: CanvasSize(width: 4_096, height: 1_024)))

        #expect(plan.scale == 0.5)
        #expect(plan.isReduced)
    }

    @Test("the text of a reduced render says it was reduced")
    func reducedRenderIsSaid() async throws {
        let store = try makeTestStore("canvas-render-reduced")
        let png = png
        let tool = CanvasRenderTool { _, _, _ in
            .rendered(CanvasRenderedFrame(png: png, size: CanvasSize(width: 4_096, height: 1_024), scale: 0.5, missingFonts: []))
        }
        let result = await tool.call(
            request(["path": .string("c.udcanvas"), "frame": .string("f")]), as: identity, store: store
        )

        #expect(result.text.contains("2048"))
        #expect(result.text.contains("4096"))
    }

    @Test("a picture over the size that is sent is drawn again smaller until it fits, and the text gives the final size")
    func oversizedPictureIsReducedUntilItFits() async throws {
        let plan = try #require(CanvasRenderPlan(frameSize: CanvasSize(width: 2_000, height: 2_000)))
        var drawn: [Double] = []

        let fitted = plan.fit(maximumBytes: 100) { scale in
            drawn.append(scale)
            return Data(count: Int(400 * scale))
        }

        #expect(fitted?.scale == 0.25)
        #expect(drawn == [1, 0.5, 0.25])
        #expect(fitted?.png.count == 100)

        let store = try makeTestStore("canvas-render-fitted")
        let png = png
        let tool = CanvasRenderTool { _, _, _ in
            .rendered(CanvasRenderedFrame(png: png, size: CanvasSize(width: 2_000, height: 2_000), scale: 0.25, missingFonts: []))
        }
        let result = await tool.call(
            request(["path": .string("c.udcanvas"), "frame": .string("f")]), as: identity, store: store
        )

        #expect(!result.isError)
        #expect(result.text.contains("500 by 500 pixels"))
        #expect(result.text.contains("too large to send"))
    }

    @Test("a frame already capped at 2048 that is still too large is reduced further, and one that cannot fit gives up")
    func cappedPictureIsReducedFurther() throws {
        let plan = try #require(CanvasRenderPlan(frameSize: CanvasSize(width: 4_096, height: 1_024)))
        var drawn: [Double] = []

        let fitted = plan.fit(maximumBytes: 10) { scale in
            drawn.append(scale)
            return Data(count: scale > 0.25 ? 50 : 5)
        }
        let never = plan.fit(maximumBytes: 10) { _ in Data(count: 50) }

        #expect(drawn == [0.5, 0.25])
        #expect(fitted?.scale == 0.25)
        #expect(never == nil)
    }

    @Test("a frame size too large for an integer is written without trapping")
    func hugeSizesAreFormatted() {
        #expect(CanvasRenderPlan.points(1e300) == String(format: "%.0f", 1e300))
        #expect(CanvasRenderPlan.points(.nan).lowercased() == "nan")
        #expect(CanvasRenderPlan.points(300.4) == "300")
        #expect(CanvasRenderPlan(frameSize: CanvasSize(width: 1e300, height: 10)) == nil)
    }
}

@Suite("Fitting a small frame into a picture")
struct CanvasRenderSmallFrameTests {
    @Test(arguments: [1.0, 20.0, 60.0, 63.9])
    func aFrameUnderTheSmallestSideIsDrawnOnce(side: Double) throws {
        let plan = try #require(CanvasRenderPlan(frameSize: CanvasSize(width: side, height: side)))
        var drawn: [Double] = []

        let fitted = plan.fit(maximumBytes: 100) { scale in
            drawn.append(scale)
            return Data(count: 10)
        }

        #expect(drawn == [1])
        #expect(fitted?.scale == 1)
    }

    @Test func aSmallFrameThatStaysTooLargeIsNotHalved() throws {
        let plan = try #require(CanvasRenderPlan(frameSize: CanvasSize(width: 60, height: 60)))
        var drawn: [Double] = []

        let fitted = plan.fit(maximumBytes: 5) { scale in
            drawn.append(scale)
            return Data(count: 10)
        }

        #expect(drawn == [1])
        #expect(fitted == nil)
    }
}
