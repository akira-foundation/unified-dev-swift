import AppKit
import Core

final class ComposerTextView: NSTextView, HoverQuickLookSource {
    var previewAttachment: (@MainActor (String) -> URL?)?

    func quickLookURL(at point: NSPoint) -> URL? {
        guard let path = chip(at: point)?.path else { return nil }
        return previewAttachment?(path)
    }

    var keyHandler: (@MainActor (NSEvent, NSRange) -> Bool)?
    var onWidthChange: (@MainActor () -> Void)?
    var onFocusChange: (@MainActor (Bool) -> Void)?
    var onWindowChange: (@MainActor () -> Void)?
    var onAttach: (@MainActor ([AttachmentSource], NSRange) -> Bool)?
    var onAttachmentFailure: @MainActor @Sendable (String) -> Void = { _ in }
    var openAttachment: (@MainActor (String) -> Void)?
    var hoverAttachment: (@MainActor (String?) -> Void)?

    fileprivate var hoveredChip: HoveredChip?
    fileprivate var hoverTask: Task<Void, Never>?
    fileprivate var hoverArea: NSTrackingArea?
    private var chipHoverFractions: [HoveredChip: CGFloat] = [:]
    private var chipHoverAnimation: Task<Void, Never>?

    override func didChangeText() {
        resetChipHover()
        super.didChangeText()
    }

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event, selectedRange()) == true { return }
        super.keyDown(with: event)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(newSize.width - frame.width) > 0.5
        super.setFrameSize(newSize)
        if changed { onWidthChange?() }
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        HoverQuickLookController.shared.update(self)
        if window == nil { resetChipHover() }
        if window != nil { onWindowChange?() }
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }

    override func cancelOperation(_ sender: Any?) {
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if AttachmentDrop.canRead(sender.draggingPasteboard), onAttach != nil {
            let range = dropRange(for: sender)
            return AttachmentDrop.receive(
                sender.draggingPasteboard,
                onReceive: { [weak self] sources in self?.onAttach?(sources, range) ?? false },
                onFailure: onAttachmentFailure
            )
        }
        return super.performDragOperation(sender)
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if onAttach != nil, AttachmentDrop.canRead(sender.draggingPasteboard) { return true }
        return super.prepareForDragOperation(sender)
    }

    private func dropRange(for sender: any NSDraggingInfo) -> NSRange {
        let point = convert(sender.draggingLocation, from: nil)
        return NSRange(location: characterIndexForInsertion(at: point), length: 0)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        AttachmentDrop.canRead(sender.draggingPasteboard) ? .copy : super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        AttachmentDrop.canRead(sender.draggingPasteboard) ? .copy : super.draggingUpdated(sender)
    }

    override func paste(_ sender: Any?) {
        let sources = Self.attachables(on: .general)
        if !sources.isEmpty, onAttach?(sources, selectedRange()) == true { return }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        let sources = Self.attachables(on: .general)
        if !sources.isEmpty, onAttach?(sources, selectedRange()) == true { return }
        super.pasteAsPlainText(sender)
    }

    override func writeSelection(
        to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType
    ) -> Bool {
        guard type == .string, let storage = textStorage else {
            return super.writeSelection(to: pasteboard, type: type)
        }
        let text = selectedRanges
            .map { ComposerChipText.draft(of: storage, in: $0.rangeValue) }
            .joined(separator: "\n")
        pasteboard.setString(text, forType: .string)
        return true
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)) || item.action == #selector(pasteAsPlainText(_:)) {
            if super.validateUserInterfaceItem(item) { return true }
            return Self.hasAttachables(on: .general)
        }
        return super.validateUserInterfaceItem(item)
    }
}

extension ComposerTextView {
    private static var hoverDelay: Duration { Motion.hoverCardDelay }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        guard hoverAttachment != nil else { return }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        hover(over: chip(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hover(over: nil)
    }

    private func chip(at point: CGPoint) -> HoveredChip? {
        guard let layout = layoutManager, let container = textContainer else { return nil }
        let origin = textContainerOrigin
        let inContainer = CGPoint(x: point.x - origin.x, y: point.y - origin.y)

        var fraction: CGFloat = 0
        let glyph = layout.glyphIndex(
            for: inContainer, in: container, fractionOfDistanceThroughGlyph: &fraction
        )
        guard layout.numberOfGlyphs > glyph else { return nil }

        let rect = layout.boundingRect(
            forGlyphRange: NSRange(location: glyph, length: 1), in: container
        )
        guard rect.contains(inContainer) else { return nil }

        let index = layout.characterIndexForGlyph(at: glyph)
        guard index < (string as NSString).length else { return nil }
        guard let storage = textStorage,
              let path = ComposerChipText.subject(of: storage, at: index)?.path
        else { return nil }
        return HoveredChip(path: path, index: index)
    }

    private func hover(over chip: HoveredChip?) {
        guard chip != hoveredChip else { return }
        hoveredChip = chip
        hoverTask?.cancel()
        animateChipHover()

        guard let chip else {
            hoverAttachment?(nil)
            return
        }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hoverDelay)
            guard !Task.isCancelled, let self, self.hoveredChip == chip else { return }
            self.hoverAttachment?(chip.path)
        }
    }

    private func resetChipHover() {
        hoverTask?.cancel()
        chipHoverAnimation?.cancel()
        chipHoverAnimation = nil
        chipHoverFractions.removeAll()
        hoveredChip = nil
        hoverAttachment?(nil)
        needsDisplay = true
    }

    private func animateChipHover() {
        chipHoverAnimation?.cancel()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            chipHoverAnimation = nil
            chipHoverFractions = hoveredChip.map { [$0: 1] } ?? [:]
            needsDisplay = true
            return
        }

        if let hoveredChip, chipHoverFractions[hoveredChip] == nil {
            chipHoverFractions[hoveredChip] = 0
        }
        let initial = chipHoverFractions
        let target = hoveredChip
        let clock = ContinuousClock()
        let start = clock.now
        chipHoverAnimation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = min(1, (clock.now - start) / .milliseconds(180))
                let eased = CGFloat(1 - pow(1 - elapsed, 3))
                for (chip, fraction) in initial {
                    let destination: CGFloat = chip == target ? 1 : 0
                    self.chipHoverFractions[chip] = fraction + (destination - fraction) * eased
                    if chip.index < (self.textStorage?.length ?? 0) {
                        self.layoutManager?.invalidateDisplay(
                            forCharacterRange: NSRange(location: chip.index, length: 1)
                        )
                    }
                }
                if elapsed == 1 {
                    self.chipHoverFractions = target.map { [$0: 1] } ?? [:]
                    self.chipHoverAnimation = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func chipHoverFraction(at characterIndex: Int) -> CGFloat {
        guard let storage = textStorage,
              characterIndex >= 0, characterIndex < storage.length,
              let path = ComposerChipText.subject(of: storage, at: characterIndex)?.path
        else { return 0 }
        return chipHoverFractions[HoveredChip(path: path, index: characterIndex)] ?? 0
    }
}

struct HoveredChip: Hashable {
    var path: String
    var index: Int
}

extension ComposerTextView {
    func isChipHovered(at characterIndex: Int) -> Bool {
        hoveredChip?.index == characterIndex
    }

    func removeAttachment(at characterIndex: Int) {
        guard let storage = textStorage else { return }
        let held = attributedString()
        let chips = ComposerChipText.attachments(in: held)
        let draft = ComposerChipText.draft(of: held)
        let parsed = AttachmentDraft.parse(draft, paths: chips.map(\.path))
        guard let occurrence = parsed.attachment(
            startingAt: ComposerChipText.draftOffset(forStorage: characterIndex, in: held)
        ), let cut = parsed.removal(ofAttachment: occurrence) else { return }
        let start = ComposerChipText.storageOffset(forDraft: cut.location, in: held)
        let end = ComposerChipText.storageOffset(forDraft: cut.upperBound, in: held)
        let range = NSRange(location: start, length: max(end - start, 0))

        breakUndoCoalescing()
        guard shouldChangeText(in: range, replacementString: "") else { return }
        storage.beginEditing()
        storage.replaceCharacters(in: range, with: "")
        storage.endEditing()
        didChangeText()
        breakUndoCoalescing()
        undoManager?.setActionName("Remove Attachment")
        setSelectedRange(NSRange(location: range.location, length: 0))
        hover(over: nil)
    }
}
