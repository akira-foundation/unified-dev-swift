import Foundation
import UniformTypeIdentifiers

public enum MediaShowToolName {
    public static let show = "media_show"
}

public enum WorkspaceMediaKind: String, Sendable, Hashable {
    case image
    case video
}

public struct WorkspaceMedia: Sendable, Hashable {
    public let url: URL
    public let relativePath: String
    public let kind: WorkspaceMediaKind

    public init(url: URL, relativePath: String, kind: WorkspaceMediaKind) {
        self.url = url
        self.relativePath = relativePath
        self.kind = kind
    }

    public static func resolve(path: String, in worktree: String) -> WorkspaceMedia? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.hasPrefix("/") || !worktree.isEmpty else { return nil }

        let root = URL(filePath: worktree, directoryHint: .isDirectory)
            .resolvingSymlinksInPath().standardizedFileURL
        let candidate = trimmed.hasPrefix("/")
            ? URL(filePath: trimmed)
            : root.appending(path: trimmed)
        let file = candidate.resolvingSymlinksInPath().standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              let type = UTType(filenameExtension: file.pathExtension)
        else { return nil }

        let kind: WorkspaceMediaKind
        if type.conforms(to: .image) {
            kind = .image
        } else if type.conforms(to: .movie) {
            kind = .video
        } else {
            return nil
        }

        return WorkspaceMedia(url: file, relativePath: display(of: file, under: root), kind: kind)
    }

    private static func display(of file: URL, under root: URL) -> String {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard !root.path.isEmpty, file.path.hasPrefix(prefix) else { return file.lastPathComponent }
        let relative = String(file.path.dropFirst(prefix.count))
        return relative.isEmpty ? file.lastPathComponent : relative
    }

    public static func resolveImageView(path: String, in worktree: String) -> WorkspaceMedia? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.hasPrefix("/"), worktree.isEmpty { return nil }
        let candidate = trimmed.hasPrefix("/")
            ? URL(filePath: trimmed)
            : URL(filePath: worktree, directoryHint: .isDirectory).appending(path: trimmed)
        let file = candidate.resolvingSymlinksInPath().standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              let type = UTType(filenameExtension: file.pathExtension),
              type.conforms(to: .image)
        else { return nil }

        return WorkspaceMedia(url: file, relativePath: file.lastPathComponent, kind: .image)
    }
}

public struct MediaShowOrder: Sendable, Hashable {
    public let path: String
    public let caption: String

    public init(path: String, caption: String = "") {
        self.path = path
        self.caption = caption
    }
}

public enum MediaShowOutcome: Sendable, Hashable {
    case shown(String)
    case refused(String)
}

public typealias MediaShowing = @MainActor @Sendable (
    _ order: MediaShowOrder, _ workspaceID: WorkspaceID
) async -> MediaShowOutcome

public struct MediaShowRequest: Sendable, Hashable {
    public let path: String
    public let caption: String

    public init(path: String, caption: String = "") {
        self.path = path
        self.caption = caption
    }

    public init?(use: AgentToolUse) {
        let expected = "mcp__\(BridgeRegistration.serverName)__\(MediaShowToolName.show)"
        guard use.name == expected,
              let path = use.input["path"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty
        else { return nil }
        self.path = path
        self.caption = use.input["caption"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

public struct CodexImageViewRequest: Sendable, Hashable {
    public let path: String

    public init?(use: AgentToolUse) {
        guard case .other(let type, _, let json)? = CodexTranslation.item(in: use.input),
              type == "imageView",
              let path = json["path"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty
        else { return nil }
        self.path = path
    }
}

public enum MediaShowRow {
    private static let probeLength = 1_024
    private static let marker = Data(
        "mcp__\(BridgeRegistration.serverName)__\(MediaShowToolName.show)".utf8
    )

    public static func isCall(_ payload: Data) -> Bool {
        payload.prefix(probeLength).range(of: marker) != nil
    }
}

public enum CodexImageViewRow {
    private static let probeLength = 1_024
    private static let marker = Data("\"type\":\"imageView\"".utf8)

    public static func isCall(_ payload: Data) -> Bool {
        payload.prefix(probeLength).range(of: marker) != nil
    }
}

public struct MediaShowTool: BridgeToolHandling {
    private let show: MediaShowing

    public init(_ show: @escaping MediaShowing) { self.show = show }

    public let roles = BridgeWorkspaceScope.roles
    public let tool = BridgeTool(
        name: MediaShowToolName.show,
        description: """
            Show a local image or video inline in this workspace's chat, where the person can see \
            it without opening anything. Use it whenever what you have to say is a picture: a \
            screenshot you just took, a mockup, a generated image, a chart, an animation, a screen \
            recording. Reach for it in particular when you are asked to SHOW something, or when \
            you have just written an image somewhere and are about to describe it in words \
            instead. Reading an image file tells YOU what is in it; this is what puts it in front \
            of the person you are working for.

            The file only has to exist and be an image or a movie in a format macOS recognises. \
            It does not have to be inside the workspace: a screenshot in a temporary folder is \
            the ordinary case and works. Nothing is uploaded or copied.

            'path' is workspace-relative or absolute. 'caption' is optional and should be one \
            short sentence that adds context not obvious from the media.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The image or video file to show."),
                ]),
                "caption": .object([
                    "type": .string("string"),
                    "description": .string("An optional short caption."),
                ]),
            ]),
            "required": .array([.string("path")]),
        ])
    )

    public func call(
        _ request: MCPRequest, as identity: BridgeIdentity, store: Store
    ) async -> BridgeToolResult {
        guard let workspaceID = identity.workspaceID else {
            return .failure(
                BridgeWorkspaceScope.refusal(tool: MediaShowToolName.show, doing: "shows a file in")
            )
        }
        let path = request.stringParam("path")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else { return .failure("media_show needs a non-empty 'path'.") }
        let caption = request.stringParam("caption")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch await show(MediaShowOrder(path: path, caption: caption), workspaceID) {
        case .shown(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let sentence): return .failure(sentence)
        }
    }
}
