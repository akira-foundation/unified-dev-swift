import AppKit
import Core

extension ComposerPrompt {
    func receiveDrop(_ sources: [AttachmentSource]) -> Bool {
        let paths = DroppedFolders.paths(sources)
        guard ComposerDropQuestions.needsAsking(paths) else {
            return take(sources, answers: ComposerDropQuestions.nothingAsked(count: sources.count))
        }
        let root = mentionRoot
        let ownerAtDrop = currentDropOwner
        Task {
            let answers = await ComposerDropQuestions.answer(paths: paths, under: root)
            guard ComposerFolderDrop.isSameDraft(ownerAtDrop: ownerAtDrop, ownerNow: currentDropOwner) else {
                return attachmentFailed(ComposerFolderDrop.changedOwnerNotice)
            }
            _ = take(sources, answers: answers)
        }
        return true
    }

    private func take(_ sources: [AttachmentSource], answers: ComposerDropAnswers) -> Bool {
        var draft = command
        let plan = ComposerFolderDrop.plan(
            answers.items, roots: answers.roots, before: String(draft.body.suffix(1))
        )
        var end = (draft.body as NSString).length
        if plan.writesText {
            draft.body += plan.insertion
            text = draft.text
            end = (draft.body as NSString).length
            caret = end
            isFocused = true
        }
        if let notice = plan.omissionNotice { attachmentFailed(notice) }

        let attachments = plan.attachmentIndices.map { sources[$0] }
        guard !attachments.isEmpty else { return plan.writesText }
        let attached = attach(
            sources: attachments, replacing: NSRange(location: end, length: 0)
        )
        return plan.tookTheDrop(attached: attached)
    }
}
