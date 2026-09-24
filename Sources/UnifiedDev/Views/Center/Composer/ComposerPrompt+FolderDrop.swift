import AppKit
import Core

extension ComposerPrompt {
    func receiveDrop(_ sources: [AttachmentSource]) -> Bool {
        var draft = command
        let plan = ComposerFolderDrop.plan(
            DroppedFolders.items(sources),
            roots: DroppedFolders.roots(under: mentionRoot),
            before: String(draft.body.suffix(1))
        )
        var end = (draft.body as NSString).length
        if plan.writesText {
            draft.body += plan.insertion
            text = draft.text
            end = (draft.body as NSString).length
            caret = end
            isFocused = true
        }

        let attachments = plan.attachmentIndices.map { sources[$0] }
        guard !attachments.isEmpty else { return plan.writesText }
        let attached = attach(
            sources: attachments, replacing: NSRange(location: end, length: 0)
        )
        return plan.tookTheDrop(attached: attached)
    }
}
