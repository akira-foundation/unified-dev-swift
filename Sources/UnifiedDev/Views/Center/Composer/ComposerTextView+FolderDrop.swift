import AppKit
import Core

extension ComposerTextView {
    func receiveDrop(_ sources: [AttachmentSource], at range: NSRange) -> Bool {
        let root = dropRoot?() ?? ""
        let paths = DroppedFolders.paths(sources)
        guard !root.isEmpty, ComposerDropQuestions.needsAsking(paths) else {
            return onAttach?(sources, range) == true
        }
        let textAtDrop = string
        let ownerAtDrop = dropOwner?() ?? ""
        Task { [weak self] in
            let answers = await ComposerDropQuestions.answer(paths: paths, under: root)
            guard let self else { return }
            guard ComposerFolderDrop.isSameDraft(ownerAtDrop: ownerAtDrop, ownerNow: dropOwner?() ?? "") else {
                return onAttachmentFailure(ComposerFolderDrop.changedOwnerNotice)
            }
            take(sources, answers: answers, dropped: range, textAtDrop: textAtDrop)
        }
        return true
    }

    private func take(
        _ sources: [AttachmentSource],
        answers: ComposerDropAnswers,
        dropped: NSRange,
        textAtDrop: String
    ) {
        let range = ComposerFolderDrop.insertionRange(
            dropped: dropped, textAtDrop: textAtDrop, textNow: string, selection: selectedRange()
        )
        let plan = ComposerFolderDrop.plan(
            answers.items,
            roots: answers.roots,
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
        if let notice = plan.omissionNotice { onAttachmentFailure(notice) }
        guard !attachments.isEmpty else { return }
        _ = onAttach?(attachments, attachmentRange)
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
