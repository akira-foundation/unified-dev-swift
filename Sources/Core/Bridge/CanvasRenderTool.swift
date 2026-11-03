import Foundation

public enum CanvasRenderToolName {
    public static let render = "canvas_render"
}

public struct CanvasRenderPlan: Sendable, Equatable {
    public static let largestFrameSide = 8_192.0
    public static let largestPictureSide = 2_048.0

    public let frameSize: CanvasSize
    public let scale: Double

    public init?(frameSize: CanvasSize) {
        let longest = max(frameSize.width, frameSize.height)
        guard frameSize.width.isFinite, frameSize.height.isFinite,
              frameSize.width > 0, frameSize.height > 0, longest <= Self.largestFrameSide else { return nil }
        self.frameSize = frameSize
        scale = longest > Self.largestPictureSide ? Self.largestPictureSide / longest : 1
    }

    public var isReduced: Bool { scale < 1 }

    public var pixelSize: CanvasSize {
        CanvasSize(width: (frameSize.width * scale).rounded(), height: (frameSize.height * scale).rounded())
    }
}

public struct CanvasRenderedFrame: Sendable, Equatable {
    public var png: Data
    public var size: CanvasSize
    public var missingFonts: [String]

    public init(png: Data, size: CanvasSize, missingFonts: [String]) {
        self.png = png
        self.size = size
        self.missingFonts = missingFonts
    }
}

public enum CanvasRenderOutcome: Sendable, Equatable {
    case rendered(CanvasRenderedFrame)
    case refused(String)
}

public typealias CanvasRendering = @MainActor @Sendable (
    _ path: String, _ frame: CanvasFrameID, _ workspaceID: WorkspaceID
) async -> CanvasRenderOutcome

public struct CanvasRenderTool: BridgeToolHandling {
    private let rendering: CanvasRendering

    public init(_ rendering: @escaping CanvasRendering) { self.rendering = rendering }

    public let roles = BridgeWorkspaceScope.roles
    public let tool = BridgeTool(
        name: CanvasRenderToolName.render,
        description: """
            See one frame of a canvas document in this workspace as a picture, drawn by the same code \
            as the screen: every element in it, with no selection and nothing hidden because the person \
            is editing it. Use it after canvas_edit to check what you drew, a title that overflows or \
            two things that overlap. Works whether or not the canvas is open in a tab.

            The frame is drawn at 1:1, one point to one pixel, up to 8192 points a side. When the \
            picture would be too large to send, its longest side is capped at 2048 pixels and the text \
            says so. Fonts the document names that this Mac does not have are listed in the text, and \
            are drawn in the system font.

            'path' is workspace-relative or absolute and must name a canvas document inside this \
            workspace. 'frame' is a frame id from canvas_read.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The canvas document, inside this workspace."),
                ]),
                "frame": .object([
                    "type": .string("string"),
                    "description": .string("The id of the frame to draw, as canvas_read gives it."),
                ]),
            ]),
            "required": .array([.string("path"), .string("frame")]),
        ])
    )

    public func call(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: CanvasRenderToolName.render, doing: "renders a canvas in")
            )
        }
        let path = request.stringParam("path")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else { return .failure("canvas_render needs a non-empty 'path'.") }
        let frame = request.stringParam("frame")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !frame.isEmpty else { return .failure("canvas_render needs the 'frame' to draw, an id from canvas_read.") }

        switch await rendering(path, CanvasFrameID(frame), workspaceID) {
        case .refused(let sentence): return .failure(sentence)
        case .rendered(let rendered): return Self.result(for: rendered)
        }
    }

    private static func result(for rendered: CanvasRenderedFrame) -> BridgeToolResult {
        let image = BridgeToolImage(png: rendered.png)
        guard !image.isTooLarge else {
            return .failure(
                "That frame came out at \(image.data.count / 1_024) KB, which is more than Unified Dev will send "
                    + "in one answer. Read it with canvas_read instead."
            )
        }
        return .picture(image, saying: sentence(for: rendered))
    }

    private static func sentence(for rendered: CanvasRenderedFrame) -> String {
        let size = rendered.size
        var sentence = "Frame drawn at \(Int(size.width)) by \(Int(size.height)) points."
        if let plan = CanvasRenderPlan(frameSize: size), plan.isReduced {
            let pixels = plan.pixelSize
            sentence += " The longest side is capped at \(Int(CanvasRenderPlan.largestPictureSide)) pixels, "
                + "so this picture is \(Int(pixels.width)) by \(Int(pixels.height)) pixels, "
                + "not 1:1 with the \(Int(size.width)) by \(Int(size.height)) points."
        }
        if !rendered.missingFonts.isEmpty {
            sentence += " This Mac does not have \(rendered.missingFonts.joined(separator: ", ")), "
                + "so the text in those fonts is drawn in the system font."
        }
        return sentence
    }
}
