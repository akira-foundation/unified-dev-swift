import AppKit
import Core

extension ComposerTextView {
    func receiveDrop(_ sources: [AttachmentSource], at range: NSRange) -> Bool {
        let roots = DroppedFolders.roots(under: dropRoot?() ?? "")
        guard !roots.isEmpty else { return onAttach?(sources, range) == true }

        let plan = ComposerFolderDrop.plan(
            DroppedFolders.items(sources),
            roots: roots,
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
