import Foundation

public enum CanvasRenderToolName {
    public static let render = "canvas_render"
}

public struct CanvasRenderPlan: Sendable, Equatable {
    public static let largestPictureSide = 2_048.0

    public let frameSize: CanvasSize
    public let scale: Double

    public init?(frameSize: CanvasSize) {
        let longest = max(frameSize.width, frameSize.height)
        guard frameSize.width.isFinite, frameSize.height.isFinite,
              frameSize.width > 0, frameSize.height > 0, longest <= CanvasFrameSize.maximum else { return nil }
        self.frameSize = frameSize
        scale = longest > Self.largestPictureSide ? Self.largestPictureSide / longest : 1
    }

    public var isReduced: Bool { scale < 1 }

    public static func points(_ value: Double) -> String { String(format: "%.0f", value) }

    public static let smallestPictureSide = 64.0

    public func fit(maximumBytes: Int = BridgeToolImage.maximumBytes, draw: (Double) -> Data?) -> CanvasFittedRender? {
        var scale = scale
        let longest = max(frameSize.width, frameSize.height)
        repeat {
            guard let png = draw(scale) else { return nil }
            if png.count <= maximumBytes { return CanvasFittedRender(png: png, scale: scale) }
            scale /= 2
        } while longest * scale >= Self.smallestPictureSide
        return nil
    }
}

public struct CanvasFittedRender: Sendable, Equatable {
    public var png: Data
    public var scale: Double
}

public struct CanvasRenderedFrame: Sendable, Equatable {
    public var png: Data
    public var size: CanvasSize
    public var scale: Double
    public var missingFonts: [String]
    public var warning: String?

    public init(png: Data, size: CanvasSize, scale: Double = 1, missingFonts: [String], warning: String? = nil) {
        self.png = png
        self.size = size
        self.scale = scale
        self.missingFonts = missingFonts
        self.warning = warning
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
            are drawn in the system font. When saving is paused the text says so: the picture is the \
            canvas as the tab holds it, not the file on disk.

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
                    + "in one answer, and it could not be made smaller. Split it into smaller frames."
            )
        }
        return .picture(image, saying: sentence(for: rendered))
    }

    private static func sentence(for rendered: CanvasRenderedFrame) -> String {
        let size = rendered.size
        let width = CanvasRenderPlan.points(size.width)
        let height = CanvasRenderPlan.points(size.height)
        var sentence = "Frame drawn at \(width) by \(height) points."
        if rendered.scale < 1 {
            let pixels = "\(CanvasRenderPlan.points(size.width * rendered.scale)) by \(CanvasRenderPlan.points(size.height * rendered.scale))"
            let plan = CanvasRenderPlan(frameSize: size)
            let cap = "The longest side is capped at \(Int(CanvasRenderPlan.largestPictureSide)) pixels"
            let reason = switch (plan?.isReduced == true, rendered.scale < (plan?.scale ?? 1)) {
            case (true, false): cap
            case (true, true): cap + " and the picture was still too large to send"
            case (false, _): "The picture was too large to send at that size"
            }
            sentence += " \(reason), so this picture is \(pixels) pixels, not 1:1 with the \(width) by \(height) points."
        }
        if !rendered.missingFonts.isEmpty {
            sentence += " This Mac does not have \(CanvasFileText.list(rendered.missingFonts)), "
                + "so the text in those fonts is drawn in the system font. \(CanvasFileText.isFromFile)"
        }
        if let warning = rendered.warning { sentence += " \(warning)" }
        return sentence
    }
}
