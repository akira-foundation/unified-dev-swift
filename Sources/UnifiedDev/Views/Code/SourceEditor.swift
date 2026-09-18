import SwiftUI
import AppKit
import Core

struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    var language: Language
    var colorScheme: ColorScheme
    var isEditable = true
    var ground: Color?
    var placeholder = ""
    var editorState: SourceEditorState?
    var onOpenReference: ((String, Int, Bool) -> Void)?
    var onDefinition: ((Int) -> Void)?
    var onReferences: ((Int) -> Void)?
    var onNavigateSymbol: ((Int, Bool) -> Void)?
    var onAsk: (() -> Void)?

    private static let highlightLimit = 400_000

    private var resolvedGround: NSColor {
        guard let ground else { return .clear }
        return NSColor(ground)
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(
            size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        )
        container.widthTracksTextView = false
        layoutManager.addTextContainer(container)

        let textView = CodeTextView(frame: .zero, textContainer: container)
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.textContainerInset = NSSize(width: CodeMetrics.textInset, height: 6)
        textView.font = CodeMetrics.font
        textView.backgroundColor = resolvedGround
        textView.drawsBackground = ground != nil
        textView.placeholder = placeholder
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = ground != nil
        scrollView.backgroundColor = resolvedGround

        let ruler = LineNumberRuler(scrollView: scrollView, textView: textView)
        ruler.fill = resolvedGround
        ruler.numberColor = NSColor(Palette.textTertiary)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.documentView = textView
        scrollView.tile()

        context.coordinator.attach(textView: textView, ruler: ruler)
        context.coordinator.replace(text: text, language: language, appearance: colorScheme)
        configure(textView, scrollView: scrollView)
        if let editorState {
            let length = textView.string.utf16.count
            let start = min(editorState.selection.location, length)
            textView.setSelectedRange(NSRange(location: start, length: min(editorState.selection.length, length - start)))
            scrollView.contentView.scroll(to: editorState.scrollOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        context.coordinator.restorePosition()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? CodeTextView else { return }

        let ground = resolvedGround
        textView.backgroundColor = ground
        textView.isEditable = isEditable
        textView.placeholder = placeholder
        scrollView.backgroundColor = ground
        if let ruler = scrollView.verticalRulerView as? LineNumberRuler {
            ruler.fill = ground
            ruler.numberColor = NSColor(Palette.textTertiary)
            ruler.needsDisplay = true
        }

        configure(textView, scrollView: scrollView)

        if context.coordinator.wouldDiscardTyping(text) == false,
           textView.string != text
            || context.coordinator.language != language
            || context.coordinator.appearance != colorScheme {
            context.coordinator.replace(text: text, language: language, appearance: colorScheme)
        }
        context.coordinator.restorePosition()
    }

    private func configure(_ view: CodeTextView, scrollView: NSScrollView) {
        view.editorState = editorState
        editorState?.textView = view
        view.codeLanguage = language
        view.onOpenReference = onOpenReference
        view.onDefinition = onDefinition
        view.onReferences = onReferences
        view.onNavigateSymbol = onNavigateSymbol
        view.onAsk = onAsk
        let wraps = editorState?.wraps ?? false
        view.isHorizontallyResizable = !wraps
        view.autoresizingMask = wraps ? [.width] : []
        view.textContainer?.widthTracksTextView = wraps
        let width = wraps ? scrollView.contentSize.width : CGFloat.greatestFiniteMagnitude
        view.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        if wraps { view.setFrameSize(NSSize(width: scrollView.contentSize.width, height: view.frame.height)) }
        scrollView.hasHorizontalScroller = !wraps
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.detach()
    }

    struct ColorRun: Sendable {
        var start: Int
        var length: Int
        var kind: TokenKind
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        private(set) var language: Language = .plainText
        private(set) var appearance: ColorScheme = .light

        private weak var textView: NSTextView?
        private weak var ruler: LineNumberRuler?
        private var highlightTask: Task<Void, Never>?

        private let editorUndo = UndoManager()

        func undoManager(for view: NSTextView) -> UndoManager? {
            editorUndo
        }

        private var published: String?

        init(text: Binding<String>) {
            self.text = text
        }

        func wouldDiscardTyping(_ incoming: String) -> Bool {
            guard let textView else { return false }
            return EditorEcho.wouldDiscardTyping(
                published: published, shown: textView.string, incoming: incoming
            )
        }

        func attach(textView: NSTextView, ruler: LineNumberRuler) {
            self.textView = textView
            self.ruler = ruler
        }

        func detach() {
            if let view = textView as? CodeTextView, let state = view.editorState {
                state.selection = view.selectedRange()
                state.scrollOrigin = view.enclosingScrollView?.contentView.bounds.origin ?? .zero
                if state.textView === view { state.textView = nil }
            }
            (textView as? CodeTextView)?.updateNavigationHint(command: false)
            (textView as? CodeTextView)?.bracketTask?.cancel()
            highlightTask?.cancel()
        }

        func replace(
            text value: String, language newLanguage: Language, appearance scheme: ColorScheme
        ) {
            guard let textView else { return }
            language = newLanguage
            appearance = scheme
            if textView.string != value {
                let selection = textView.selectedRange()
                let origin = textView.enclosingScrollView?.contentView.bounds.origin
                textView.string = value
                published = value
                let start = min(selection.location, value.utf16.count)
                textView.setSelectedRange(NSRange(location: start, length: min(selection.length, value.utf16.count - start)))
                if let origin, let scroll = textView.enclosingScrollView {
                    scroll.contentView.scroll(to: origin)
                    scroll.reflectScrolledClipView(scroll.contentView)
                }
                editorUndo.removeAllActions()
            }
            ruler?.refresh()
            highlight(immediately: true)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            (textView as? CodeTextView)?.updateNavigationHint(command: false)
            published = textView.string
            text.wrappedValue = textView.string
            ruler?.refresh()
            highlight(immediately: false)
        }

        func restorePosition() {
            guard let view = textView as? CodeTextView, let state = view.editorState,
                  let request = state.request, state.appliedRevision != state.revision else { return }
            state.appliedRevision = state.revision
            let offset = CodeLocation.offset(in: view.string, line: request.line, column: request.column)
            view.setSelectedRange(NSRange(location: offset, length: 0))
            view.scrollRangeToVisible(NSRange(location: offset, length: 0))
            view.showFindIndicator(for: (view.string as NSString).lineRange(for: NSRange(location: offset, length: 0)))
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = textView as? CodeTextView else { return }
            view.needsDisplay = true
            view.updateBracketMatch()
            let selection = view.selectedRange()
            let position = CodeLocation.position(in: view.string, offset: selection.location)
            Task { @MainActor [weak view] in
                guard let view, view.selectedRange() == selection, let state = view.editorState else { return }
                state.selection = selection
                state.line = position.line
                state.column = position.column
            }
        }

        private func highlight(immediately: Bool) {
            highlightTask?.cancel()
            let source = textView?.string ?? ""
            let language = self.language

            guard source.utf16.count <= SourceEditor.highlightLimit, language != .plainText else {
                applyPlain()
                return
            }

            highlightTask = Task { [weak self] in
                if !immediately {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                }
                let runs = await Task.detached(priority: .userInitiated) {
                    SourceEditor.runs(in: source, language: language)
                }.value
                guard !Task.isCancelled else { return }
                self?.apply(runs, matching: source)
            }
        }

        private func applyPlain() {
            (textView as? CodeTextView)?.navigationSource = nil
            (textView as? CodeTextView)?.navigationTokens = []
            guard let storage = textView?.textStorage else { return }
            storage.beginEditing()
            storage.setAttributes(Self.base, range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }

        private func apply(_ runs: [ColorRun], matching source: String) {
            guard let storage = textView?.textStorage, storage.string == source else { return }

            (textView as? CodeTextView)?.navigationSource = source
            (textView as? CodeTextView)?.navigationTokens = runs
            var colors: [TokenKind: NSColor] = [:]
            for kind in TokenKind.allCases { colors[kind] = NSColor(CodeText.color(for: kind)) }

            storage.beginEditing()
            storage.setAttributes(Self.base, range: NSRange(location: 0, length: storage.length))
            for run in runs {
                let range = NSRange(location: run.start, length: run.length)
                guard NSMaxRange(range) <= storage.length, let color = colors[run.kind] else { continue }
                storage.addAttribute(.foregroundColor, value: color, range: range)
            }
            storage.endEditing()
        }

        private static let base: [NSAttributedString.Key: Any] = [
            .font: CodeMetrics.font,
            .foregroundColor: NSColor(Palette.textPrimary),
        ]
    }

    nonisolated static func runs(in source: String, language: Language) -> [ColorRun] {
        var result: [ColorRun] = []
        var state = LexState()
        var offset = 0

        for line in source.components(separatedBy: "\n") {
            let tokens = SyntaxHighlighter.tokenize(line: line, language: language, carry: &state)
            for token in tokens where token.kind != .plain {
                result.append(
                    ColorRun(
                        start: offset + token.range.lowerBound,
                        length: token.range.count,
                        kind: token.kind
                    )
                )
            }
            offset += line.utf16.count + 1
        }
        return result
    }
}

class CodeTextView: NSTextView {
    weak var editorState: SourceEditorState?
    var codeLanguage: Language = .plainText
    var onOpenReference: ((String, Int, Bool) -> Void)?
    var onDefinition: ((Int) -> Void)?
    var onReferences: ((Int) -> Void)?
    var onNavigateSymbol: ((Int, Bool) -> Void)?
    var onAsk: (() -> Void)?
    var navigationRange: NSRange?
    var navigationTokens: [SourceEditor.ColorRun] = []
    var navigationSource: String?
    var definitionChoice: ((CodeLocation) -> Void)?
    var contextOffset = 0
    var bracketRange: NSRange?
    var bracketTask: Task<Void, Never>?

    var placeholder = "" {
        didSet { if placeholder != oldValue { needsDisplay = true } }
    }

    override var textContainerInset: NSSize {
        didSet {
            if textContainerInset != oldValue, string.isEmpty, !placeholder.isEmpty {
                needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: CodeMetrics.font,
            .foregroundColor: NSColor.placeholderTextColor,
        ]
        let origin = textContainerOrigin
        let padding = textContainer?.lineFragmentPadding ?? 0
        (placeholder as NSString).draw(
            at: NSPoint(x: origin.x + padding, y: origin.y),
            withAttributes: attributes
        )
    }
}
