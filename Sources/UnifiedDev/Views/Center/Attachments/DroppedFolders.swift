import AppKit
import Core

enum DroppedFolders {
    static func items(_ sources: [AttachmentSource]) -> [ComposerDropItem] {
        sources.map(item)
    }

    static func roots(under root: String) -> [String] {
        guard !root.isEmpty else { return [] }
        let resolved = URL(filePath: root).resolvingSymlinksInPath().path
        return resolved == root ? [root] : [root, resolved]
    }

    private static func item(_ source: AttachmentSource) -> ComposerDropItem {
        guard case .file(let url) = source else { return .attachment }
        let path = url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return .attachment }
        return .folder(path)
    }
}
