import AppKit
import SwiftUI
import Core

struct TranscriptLinkActions: Sendable, Equatable {
    enum Identity: Hashable, Sendable {
        case inert
        case workspace(WorkspaceID?, pane: String?)
        case workspaceOpeningFiles(WorkspaceID?, pane: String?)
    }

    var identity: Identity = .inert

    var open: @MainActor @Sendable (URL, TranscriptLinkTarget) -> Void = { _, _ in }
    var items: @MainActor @Sendable (URL) -> [TranscriptLinkItem] = {
        TranscriptLinkMenu.items(for: $0, placement: .detached)
    }
    var openFile: @MainActor @Sendable (String) -> Void = { _ in }
    var hoverFile: @MainActor @Sendable (FileChipHover?) -> Void = { _ in }
    var previewFile: @MainActor @Sendable (String) -> URL? = { _ in nil }

    var previewSource: @MainActor @Sendable (URL) -> URL? = { _ in nil }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
}

struct FileChipHover: Equatable, Sendable {
    var subject: InlineChip
    var frame: CGRect
}

struct TranscriptTextView: NSViewRepresentable {
    var text: NSAttributedString
    var linkColor: NSColor
    var selectionColor: NSColor
    var alignsBubbleInk = false
    var actions = TranscriptLinkActions()

    func makeCoordinator() -> Coordinator { Coordinator(actions: actions) }

    func makeNSView(context: Context) -> LinkTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)

        let view = LinkTextView(frame: .zero, textContainer: container)
        view.delegate = context.coordinator
        view.actions = actions
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.backgroundColor = NSColor.clear
        view.textContainerInset = NSSize.zero
        view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticDataDetectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isGrammarCheckingEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.usesFontPanel = false
        view.usesFindBar = false
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        apply(to: view)
        return view
    }

    func updateNSView(_ view: LinkTextView, context: Context) {
        context.coordinator.actions = actions
        view.actions = actions
        apply(to: view)
    }

    private func apply(to view: LinkTextView) {
        if view.textStorage?.isEqual(to: text) != true {
            view.textStorage?.setAttributedString(text)
            view.bubbleAlignmentWidth = nil
        }
        view.linkColor = linkColor
        view.linkTextAttributes = [
            .foregroundColor: linkColor,
            .cursor: NSCursor.pointingHand,
        ]
        view.selectedTextAttributes = [.backgroundColor: selectionColor]
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LinkTextView, context: Context) -> CGSize? {
        guard let container = nsView.textContainer, let layout = nsView.layoutManager else {
            return nil
        }
        let proposed = proposal.width.map(Double.init)
        let width = TranscriptTextMeasure.layoutWidth(proposed: proposed)
        let wanted = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        if container.containerSize != wanted { container.containerSize = wanted }
        layout.ensureLayout(for: container)
        if alignsBubbleInk {
            if nsView.bubbleAlignmentWidth != width {
                nsView.bubbleInkOffset = BubbleTextAlignment.offset(layout: layout, container: container)
                nsView.bubbleAlignmentWidth = width
            }
        } else {
            nsView.bubbleInkOffset = 0
            nsView.bubbleAlignmentWidth = nil
        }
        let used = layout.usedRect(for: container)
        let size = TranscriptTextMeasure.size(
            widestLine: Double(widestLine(layout, in: container)),
            usedHeight: Double(used.height),
            proposed: proposed,
            lineHeight: Double(lineHeight(nsView, layout)),
            hasGlyphs: (nsView.textStorage?.length ?? 0) > 0
        )
        return CGSize(width: size.width, height: size.height)
    }

    private func lineHeight(_ view: LinkTextView, _ layout: NSLayoutManager) -> CGFloat {
        let font = view.textStorage?.length ?? 0 > 0
            ? view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            : nil
        return layout.defaultLineHeight(for: font ?? .systemFont(ofSize: NSFont.systemFontSize))
    }

    private func widestLine(_ layout: NSLayoutManager, in container: NSTextContainer) -> CGFloat {
        var widest: CGFloat = 0
        layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, usedRect, _, _, _ in
            widest = max(widest, usedRect.maxX)
        }
        return widest
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var actions: TranscriptLinkActions

        init(actions: TranscriptLinkActions) { self.actions = actions }

        func textView(_ view: NSTextView, clickedOnLink link: Any, at index: Int) -> Bool {
            guard let url = Self.url(from: link) else { return false }
            actions.open(url, .externalBrowser)
            return true
        }

        static func url(from link: Any) -> URL? {
            if let url = link as? URL { return url }
            if let text = link as? String { return URL(string: text) }
            return nil
        }
    }
}

final class LinkTextView: NSTextView, HoverQuickLookSource {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        HoverQuickLookController.shared.update(self)
    }

    func quickLookURL(at point: NSPoint) -> URL? {
        if let path = fileChip(at: point)?.subject.path { return actions.previewFile(path) }
        guard let url = link(at: point) else { return nil }
        return actions.previewSource(url)
    }

    var bubbleAlignmentWidth: CGFloat?
    var bubbleInkOffset: CGFloat = 0 {
        didSet {
            if oldValue != bubbleInkOffset { needsDisplay = true }
        }
    }

    override var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin
        return NSPoint(x: origin.x, y: origin.y + bubbleInkOffset)
    }

    var actions = TranscriptLinkActions()
    var linkColor: NSColor = .linkColor

    private var hovered: NSRange?

    private var hoveredChip: FileChipHover?

    private static let ownTrackingArea = "unifieddev.transcriptTextView.tracking"

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.userInfo?[Self.ownTrackingArea] != nil {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: [Self.ownTrackingArea: true]
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        let link = linkRange(at: point)
        let chip = fileChip(at: point)
        hover(link)
        pointer(link: link != nil, chip: chip).set()
        hoverChip(chip)
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pointer(link: linkRange(at: point) != nil, chip: fileChip(at: point)).set()
    }

    private func pointer(link: Bool, chip: FileChipHover?) -> NSCursor {
        switch TranscriptPointer.over(link: link, chipThatOpens: chip?.subject.path != nil) {
        case .hand: NSCursor.pointingHand
        case .text: NSCursor.iBeam
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let chip = fileChip(at: convert(event.locationInWindow, from: nil)),
              let path = chip.subject.path
        else {
            super.mouseDown(with: event)
            return
        }
        actions.openFile(path)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hover(nil)
        hoverChip(nil)
    }

    private func hover(_ range: NSRange?) {
        guard range != hovered, let layout = layoutManager else { return }
        if let hovered {
            layout.removeTemporaryAttribute(.underlineStyle, forCharacterRange: hovered)
        }
        if let range {
            layout.addTemporaryAttributes(
                [.underlineStyle: NSUnderlineStyle.single.rawValue], forCharacterRange: range
            )
        }
        hovered = range
    }

    private func hoverChip(_ chip: FileChipHover?) {
        guard chip != hoveredChip else { return }
        hoveredChip = chip
        actions.hoverFile(chip)
    }

    private func linkRange(at point: CGPoint) -> NSRange? {
        guard let layout = layoutManager, let container = textContainer,
              let storage = textStorage, storage.length > 0 else { return nil }

        let point = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let index = layout.characterIndex(
            for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard index < storage.length else { return nil }

        let glyph = layout.glyphIndexForCharacter(at: index)
        let bounds = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard bounds.insetBy(dx: -1, dy: 0).contains(point) else { return nil }

        var range = NSRange()
        guard storage.attribute(.link, at: index, effectiveRange: &range) != nil else { return nil }
        return range
    }

    private func fileChip(at point: CGPoint) -> FileChipHover? {
        guard let layout = layoutManager, let container = textContainer,
              let storage = textStorage, storage.length > 0 else { return nil }

        let point = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let index = layout.characterIndex(
            for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard index < storage.length else { return nil }

        let glyph = layout.glyphIndexForCharacter(at: index)
        let bounds = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard bounds.contains(point) else { return nil }

        guard let subject = ComposerChipText.subject(of: storage, at: index) else { return nil }

        let origin = textContainerOrigin
        return FileChipHover(subject: subject, frame: bounds.offsetBy(dx: origin.x, dy: origin.y))
    }

    private func link(at point: CGPoint) -> URL? {
        guard let range = linkRange(at: point), let storage = textStorage else { return nil }
        return TranscriptTextView.Coordinator.url(from: storage.attribute(.link, at: range.location, effectiveRange: nil) as Any)
    }

    override func writeSelection(
        to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType
    ) -> Bool {
        guard type == .string, let storage = textStorage else {
            return super.writeSelection(to: pasteboard, type: type)
        }
        let text = selectedRanges
            .map { TranscriptLink.selectedText(in: storage, range: $0.rangeValue) }
            .joined(separator: "\n")
        pasteboard.setString(text, forType: .string)
        return true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let url = link(at: point) else { return super.menu(for: event) }

        let menu = NSMenu()
        for offered in actions.items(url) {
            menu.addItem(item(offered.title, url: url, target: offered.target))
        }
        if let file = actions.previewSource(url), QuickLookTarget.url(for: file.path) != nil {
            let preview = NSMenuItem(title: "Quick Look", action: #selector(previewSource(_:)), keyEquivalent: "")
            preview.target = self
            preview.represent(file)
            menu.addItem(preview)
        }
        menu.addItem(.separator())
        let copy = NSMenuItem(title: "Copy Link", action: #selector(copyLink(_:)), keyEquivalent: "")
        copy.target = self
        copy.represent(url)
        menu.addItem(copy)
        return menu
    }

    private func item(_ title: String, url: URL, target: TranscriptLinkTarget) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openLink(_:)), keyEquivalent: "")
        item.target = self
        item.represent(LinkChoice(url: url, target: target))
        return item
    }

    private struct LinkChoice {
        let url: URL
        let target: TranscriptLinkTarget
    }

    @objc private func openLink(_ sender: NSMenuItem) {
        guard let choice = sender.represented(LinkChoice.self) else { return }
        actions.open(choice.url, choice.target)
    }

    @objc private func previewSource(_ sender: NSMenuItem) {
        guard let url = sender.represented(URL.self) else { return }
        HoverQuickLookController.shared.show(url, in: window)
    }

    @objc private func copyLink(_ sender: NSMenuItem) {
        guard let url = sender.represented(URL.self) else { return }
        TranscriptLink.copy(url.absoluteString)
    }
}
