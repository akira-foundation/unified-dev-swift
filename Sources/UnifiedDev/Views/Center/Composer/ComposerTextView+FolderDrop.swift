import AppKit
import Core

extension ComposerTextView {
    func receiveDrop(_ sources: [AttachmentSource], at range: NSRange) -> Bool {
        let plan = ComposerFolderDrop.plan(sources.map(Self.dropItem), worktree: resolvedDropRoot)
        let attachments = plan.attachmentIndices.map { sources[$0] }
        var attachmentRange = range
        if !plan.insertion.isEmpty {
            breakUndoCoalescing()
            insertText(plan.insertion, replacementRange: range)
            breakUndoCoalescing()
            attachmentRange = selectedRange()
        }
        guard !attachments.isEmpty else { return !plan.insertion.isEmpty }
        let attached = onAttach?(attachments, attachmentRange) == true
        return attached || !plan.insertion.isEmpty
    }

    private var resolvedDropRoot: String {
        let root = dropRoot?() ?? ""
        guard !root.isEmpty else { return "" }
        return URL(filePath: root).resolvingSymlinksInPath().path
    }

    private static func dropItem(_ source: AttachmentSource) -> ComposerDropItem {
        guard case .file(let url) = source else { return .attachment }
        let path = url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return .attachment }
        return .folder(url.resolvingSymlinksInPath().path)
    }
}
