import SwiftUI
import AppKit
import Core

struct ComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var caret: Int
    @Binding var isFocused: Bool
    var minLines: Int = 1
    var maxLines: Int = 12
    var accessibilityLabel: String = "Message"
    var onHeightChange: @MainActor (CGFloat) -> Void
    var onKey: @MainActor (ComposerKey) -> Bool
    var onBackspaceAtStart: @MainActor () -> Bool = { false }
    var onAttach: @MainActor ([AttachmentSource], NSRange) -> Bool
    var onAttachmentFailure: @MainActor @Sendable (String) -> Void = { _ in }
    var attachmentPaths: [String] = []
    var onOpenAttachment: @MainActor (String) -> Void = { _ in }
    var onHoverAttachment: @MainActor (String?) -> Void = { _ in }
    var attachmentRoot: String = ""
    var handle: ComposerEditorHandle?

    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont

    static var font: NSFont { NSFont.preferredFont(forTextStyle: .body) }

    static var lineHeight: CGFloat {
        let font = font
        if let held = heldLineHeight, held.font == font { return held.height }
        let height = NSLayoutManager().defaultLineHeight(for: font)
        heldLineHeight = (font, height)
        return height
    }

    private static var heldLineHeight: (font: NSFont, height: CGFloat)?

    static let textInset: CGFloat = 5

    static func font(scale: CGFloat, face: ChatFont) -> NSFont {
        guard scale != 1 || face != .system else { return font }
        return face.nsFont(size: (font.pointSize * scale).rounded())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)

        let textView = ComposerTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.keyHandler = { [weak coordinator = context.coordinator] event, selection in
            coordinator?.handle(event, selection: selection) ?? false
        }
        textView.onWidthChange = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.reportHeight(of: textView)
        }
        textView.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.focusChanged(to: focused)
        }
        textView.onWindowChange = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.applyFocus(to: textView)
        }
        textView.onAttach = { [weak coordinator = context.coordinator] sources, range in
            guard let coordinator else { return false }
            return coordinator.parent.onAttach(sources, coordinator.draftRange(range, in: textView))
        }
        textView.onAttachmentFailure = { [weak coordinator = context.coordinator] message in
            coordinator?.parent.onAttachmentFailure(message)
        }
        textView.openAttachment = { [weak coordinator = context.coordinator] path in
            coordinator?.parent.onOpenAttachment(path)
        }
        textView.hoverAttachment = { [weak coordinator = context.coordinator] path in
            coordinator?.parent.onHoverAttachment(path)
        }
        textView.previewAttachment = { [weak coordinator = context.coordinator] path in
            guard let coordinator else { return nil }
            return PromptAttachment.sent(path: path).url(in: coordinator.parent.attachmentRoot)
        }
        textView.registerForDraggedTypes(textView.registeredDraggedTypes + AttachmentDrop.types)
        textView.font = Self.font(scale: fontScale, face: chatFont)
        textView.textColor = .labelColor
        textView.insertionPointColor = .textInsertionPointColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.writingToolsBehavior = .none
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = CGSize(width: Self.textInset, height: 0)
        textView.autoresizingMask = [.width]
        textView.minSize = CGSize(width: 0, height: 0)
        textView.maxSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        context.coordinator.write(text, into: textView, font: textView.font ?? Self.font)
        textView.setAccessibilityLabel(accessibilityLabel)

        handle?.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComposerTextView else { return }
        context.coordinator.parent = self
        handle?.textView = textView

        let font = Self.font(scale: fontScale, face: chatFont)
        let refaced = textView.font != font
        if refaced {
            textView.font = font
        }

        let rewritesText = refaced
            || ComposerChipText.draft(of: textView.attributedString()) != text
        if rewritesText {
            context.coordinator.write(text, into: textView, font: font)
        }

        if rewritesText || caret != context.coordinator.lastReportedCaret {
            place(caretAt: caret, in: textView, coordinator: context.coordinator)
        }

        context.coordinator.applyFocus(to: textView)

        context.coordinator.reportHeight(of: textView)
    }

    private func place(caretAt caret: Int, in textView: ComposerTextView, coordinator: Coordinator) {
        let location = min(max(caret, 0), (text as NSString).length)
        textView.setSelectedRange(NSRange(
            location: ComposerChipText.storageOffset(
                forDraft: location, in: textView.attributedString()
            ),
            length: 0
        ))
        coordinator.lastReportedCaret = location
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextEditor
        var lastReportedCaret: Int?
        private var lastReportedHeight: CGFloat = 0

        init(_ parent: ComposerTextEditor) {
            self.parent = parent
        }

        func applyFocus(to textView: ComposerTextView) {
            guard let window = textView.window,
                  AutomaticFocus.mayUpdateResponder(applicationIsActive: NSApp.isActive,
                                                    windowIsKey: window.isKeyWindow,
                                                    windowIsVisible: window.isVisible) else { return }
            let holdsKeyboard = window.firstResponder === textView
            if ComposerFocus.shouldTakeKeyboard(
                wantsFocus: parent.isFocused, holdsKeyboard: holdsKeyboard,
                isReportingChange: isReportingFocus
            ) {
                window.makeFirstResponder(textView)
                return
            }

            guard ComposerFocus.shouldGiveUpKeyboard(
                wantsFocus: parent.isFocused, holdsKeyboard: holdsKeyboard
            ) else { return }
            window.makeFirstResponder(nil)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ComposerTextView else { return }
            textView.typingAttributes = [
                .font: textView.font ?? ComposerTextEditor.font,
                .foregroundColor: NSColor.labelColor,
            ]
            parent.text = ComposerChipText.draft(of: textView.attributedString())
            let caret = draftOffset(textView.selectedRange().location, in: textView)
            parent.caret = caret
            lastReportedCaret = caret
            reportHeight(of: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? ComposerTextView else { return }
            let location = draftOffset(textView.selectedRange().location, in: textView)
            lastReportedCaret = location
            if parent.caret != location { parent.caret = location }
        }

        func write(_ text: String, into textView: ComposerTextView, font: NSFont) {
            let storage = ComposerChipText.storage(
                for: text, paths: parent.attachmentPaths, font: font, color: .labelColor
            )
            textView.textStorage?.setAttributedString(storage)
            textView.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
        }

        func draftOffset(_ offset: Int, in textView: ComposerTextView) -> Int {
            ComposerChipText.draftOffset(forStorage: offset, in: textView.attributedString())
        }

        func draftRange(_ range: NSRange, in textView: ComposerTextView) -> NSRange {
            let storage = textView.attributedString()
            let start = ComposerChipText.draftOffset(forStorage: range.location, in: storage)
            let end = ComposerChipText.draftOffset(
                forStorage: range.location + range.length, in: storage
            )
            return NSRange(location: start, length: max(end - start, 0))
        }

        var isReportingFocus = false

        func focusChanged(to focused: Bool) {
            guard parent.isFocused != focused else { return }
            isReportingFocus = true
            Task { [weak self] in
                guard let self else { return }
                defer { self.isReportingFocus = false }
                guard self.parent.isFocused != focused else { return }
                self.parent.isFocused = focused
            }
        }

        func handle(_ event: NSEvent, selection: NSRange) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 36, 76: // Return, Enter
                if flags.contains(.shift) { return false }
                return parent.onKey(flags.contains(.command) ? .commandReturn : .returnKey)
            case 53: // Escape
                return parent.onKey(.escape)
            case 125: // Down
                return parent.onKey(.down)
            case 126: // Up
                return parent.onKey(.up)
            case 48: // Tab
                return parent.onKey(.tab)
            case 51: // Delete
                guard flags.isEmpty, selection.length == 0, selection.location == 0 else {
                    return false
                }
                return parent.onBackspaceAtStart()
            default:
                return false
            }
        }

        func reportHeight(of textView: ComposerTextView) {
            guard let layout = textView.layoutManager, let container = textView.textContainer else { return }
            guard textView.bounds.width > 1 else { return }

            layout.ensureLayout(for: container)

            let line = layout.defaultLineHeight(for: textView.font ?? ComposerTextEditor.font)
            let used = max(layout.usedRect(for: container).height, layout.extraLineFragmentRect.maxY)
            let minimum = CGFloat(parent.minLines) * line
            let maximum = CGFloat(parent.maxLines) * line
            let height = min(max(used, minimum), maximum).rounded(.up)

            guard abs(height - lastReportedHeight) > 0.5 else { return }
            lastReportedHeight = height
            let report = parent.onHeightChange
            Task { report(height) }
        }
    }
}

@MainActor
final class ComposerEditorHandle {
    fileprivate weak var textView: ComposerTextView?

    @discardableResult
    func insert(_ paths: [String], replacing range: NSRange, into draft: String) -> Bool {
        guard !paths.isEmpty, let textView, let storage = textView.textStorage else { return false }

        let held = textView.attributedString()
        guard ComposerChipText.draft(of: held) == draft else { return false }
        let string = held.string as NSString
        let start = min(
            ComposerChipText.storageOffset(forDraft: range.location, in: held), string.length
        )
        let end = min(
            ComposerChipText.storageOffset(
                forDraft: range.location + range.length, in: held
            ),
            string.length
        )
        let replaced = NSRange(location: start, length: max(end - start, 0))

        let before = start > 0 ? string.substring(with: NSRange(location: start - 1, length: 1)) : ""
        let after = replaced.upperBound < string.length
            ? string.substring(with: NSRange(location: replaced.upperBound, length: 1))
            : ""
        let (lead, trail) = AttachmentDraft.padding(before: before, after: after)

        let font = textView.font ?? ComposerTextEditor.font
        let plain: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let written = NSMutableAttributedString(string: lead, attributes: plain)
        for (index, path) in paths.enumerated() {
            if index > 0 {
                written.append(NSAttributedString(string: " ", attributes: plain))
            }
            written.append(ComposerChipText.chip(for: .file(path: path), font: font))
        }
        written.append(NSAttributedString(string: trail, attributes: plain))

        textView.breakUndoCoalescing()
        guard textView.shouldChangeText(in: replaced, replacementString: written.string) else {
            return false
        }
        storage.beginEditing()
        storage.replaceCharacters(in: replaced, with: written)
        storage.endEditing()
        textView.didChangeText()
        textView.breakUndoCoalescing()
        textView.undoManager?.setActionName(paths.count == 1 ? "Attach" : "Attach \(paths.count) Files")
        textView.setSelectedRange(NSRange(location: replaced.location + written.length, length: 0))
        return true
    }
}
