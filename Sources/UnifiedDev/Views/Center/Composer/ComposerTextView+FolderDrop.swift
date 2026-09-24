import AppKit
import Core

extension ComposerTextView {
    func receiveDrop(_ sources: [AttachmentSource], at range: NSRange) -> Bool {
        guard let root = dropRoot?(), !root.isEmpty else {
            return onAttach?(sources, range) == true
        }
        let plan = ComposerFolderDrop.plan(
            sources.map(Self.dropItem),
            roots: Self.roots(under: root),
            before: character(before: range),
            after: character(after: range)
        )
        let attachments = plan.attachmentIndices.map { sources[$0] }
        var attachmentRange = range
        if plan.writesText {
            breakUndoCoalescing()
            insertText(plan.insertion, replacementRange: range)
            breakUndoCoalescing()
            attachmentRange = selectedRange()
        }
        guard !attachments.isEmpty else { return plan.writesText }
        return plan.tookTheDrop(attached: onAttach?(attachments, attachmentRange) == true)
    }

    private static func roots(under root: String) -> [String] {
        let resolved = URL(filePath: root).resolvingSymlinksInPath().path
        return resolved == root ? [root] : [root, resolved]
    }

    private static func dropItem(_ source: AttachmentSource) -> ComposerDropItem {
        guard case .file(let url) = source else { return .attachment }
        let path = url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return .attachment }
        return .folder(path)
    }

    private func character(before range: NSRange) -> String {
        guard range.location > 0 else { return "" }
        return (string as NSString).substring(with: NSRange(location: range.location - 1, length: 1))
    }

    private func character(after range: NSRange) -> String {
        let text = string as NSString
        guard range.upperBound < text.length else { return "" }
        return text.substring(with: NSRange(location: range.upperBound, length: 1))
    }
}
