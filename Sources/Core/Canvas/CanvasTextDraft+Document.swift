import Foundation

extension CanvasTextDraft {
    func operations(finishingIn held: CanvasDocument) -> [CanvasOperation] {
        guard held.elements.first(where: { $0.id == elementID })?.text != text else { return [] }
        return CanvasEditing.operations(
            finishing: elementID, original: original, edited: text, measuredHeight: measuredHeight, in: held
        )
    }

    func rescuedElement(missingFrom held: CanvasDocument, before: CanvasDocument) -> CanvasElement? {
        guard !held.elements.contains(where: { $0.id == elementID }),
              let lost = before.elements.first(where: { $0.id == elementID }) else { return nil }
        var element = lost
        element.kind = lost.kind(replacingTextWith: text)
        element.revision += 1
        if let frameID = lost.frameID, !held.frames.contains(where: { $0.id == frameID }) {
            element.frameID = nil
            element.rect = CanvasHitTest.absoluteRect(of: lost, in: before)
        }
        return element
    }
}
