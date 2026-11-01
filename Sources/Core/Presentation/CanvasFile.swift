import Foundation

public enum CanvasFileResolution: Sendable, Equatable {
    case file(absolute: String, relative: String)
    case refused(String)
}

public enum CanvasFile {
    public static let extensions: Set<String> = [
        "html", "htm", "md", "markdown", "svg", "png", "jpg", "jpeg", "gif", "webp",
    ]

    public static func accepts(path: String) -> Bool {
        extensions.contains((path as NSString).pathExtension.lowercased())
    }

    public static func resolve(path: String, worktree: String) -> CanvasFileResolution {
        let located = locate(path: path, worktree: worktree)
        guard case let .file(absolute, _) = located else { return located }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absolute, isDirectory: &isDirectory) else {
            return .refused("That file does not exist in this workspace. Write it first, then call canvas_show with its path.")
        }
        guard !isDirectory.boolValue else {
            return .refused("That path is a folder. Call canvas_show with the path of a file inside it.")
        }
        return refusingType(of: located)
    }

    public static func showable(path: String, worktree: String) -> CanvasFileResolution {
        refusingType(of: locate(path: path, worktree: worktree))
    }

    private static func refusingType(of located: CanvasFileResolution) -> CanvasFileResolution {
        guard case let .file(absolute, _) = located, !accepts(path: absolute) else { return located }
        let formats = extensions.sorted().joined(separator: ", ")
        return .refused("That file type cannot be shown. Use one of: \(formats).")
    }

    private static func locate(path: String, worktree: String) -> CanvasFileResolution {
        let root = URL(filePath: worktree, directoryHint: .isDirectory)
        let requested = (path as NSString).isAbsolutePath ? URL(filePath: path) : root.appending(path: path)
        guard !worktree.isEmpty, !path.contains("\0"),
              let file = ContainedPath.resolve(requested, inside: root) else {
            return .refused("That file is not inside this workspace. Save it in the workspace, then call canvas_show with that path.")
        }
        guard DocumentPreview.isOffered(file, inside: root) else {
            return .refused("That file is withheld (repository internals and .env files are never shown). Copy what you want to show into a normal file in the workspace.")
        }
        return .file(absolute: file.path, relative: DocumentPreview.worktreePath(of: file.path, worktree: worktree))
    }
}
