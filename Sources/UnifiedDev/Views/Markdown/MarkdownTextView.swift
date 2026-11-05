import AppKit
import Core
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    var content: MarkdownText
    var actions: TranscriptLinkActions
    var runsCommands: Bool
    var fontScale: CGFloat
    var chatFont: ChatFont
    var onToggleFold: (Int) -> Void
    var onFooterHeight: (Int, CGFloat) -> Void

    func makeCoordinator() -> TranscriptTextView.Coordinator {
        TranscriptTextView.Coordinator(actions: actions)
    }

    func makeNSView(context: Context) -> LinkTextView {
        let view = TranscriptTextView.makeLinkView(delegate: context.coordinator)
        view.markdown = MarkdownTextOverlay()
        update(view, context: context)
        return view
    }

    func updateNSView(_ view: LinkTextView, context: Context) {
        update(view, context: context)
    }

    private func update(_ view: LinkTextView, context: Context) {
        context.coordinator.actions = actions
        view.actions = actions
        view.linkColor = Palette.linkNSColor
        view.linkTextAttributes = [.foregroundColor: Palette.linkNSColor, .cursor: NSCursor.pointingHand]
        view.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        view.markdown?.chrome = MarkdownTextOverlay.Chrome(
            actions: actions, runsCommands: runsCommands, fontScale: fontScale, chatFont: chatFont,
            onToggleFold: onToggleFold, onFooterHeight: onFooterHeight
        )
        view.markdown?.apply(content, to: view)
        if view.markdown?.hostsAreStale == true { view.needsLayout = true }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: LinkTextView, context: Context) -> CGSize? {
        guard let container = nsView.textContainer, let layout = nsView.layoutManager else { return nil }
        let width = max(proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? TranscriptLayout.proseMeasure, 1)
        let wanted = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        if container.containerSize != wanted {
            container.containerSize = wanted
            nsView.needsLayout = true
        }
        layout.ensureLayout(for: container)
        guard nsView.textStorage?.length ?? 0 > 0 else { return CGSize(width: width, height: 0) }
        return CGSize(width: width, height: ceil(layout.usedRect(for: container).height))
    }
}

private final class MarkdownChromeHost: NSHostingView<AnyView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

@MainActor
final class MarkdownTextOverlay {
    struct Chrome {
        var actions: TranscriptLinkActions
        var runsCommands: Bool
        var fontScale: CGFloat
        var chatFont: ChatFont
        var onToggleFold: (Int) -> Void
        var onFooterHeight: (Int, CGFloat) -> Void
    }

    var chrome: Chrome?
    private var content: MarkdownText?
    private var hosts: [Int: (header: MarkdownChromeHost, footer: MarkdownChromeHost)] = [:]
    private var hostedContent: MarkdownText?
    private var hostedActions: TranscriptLinkActions?
    private var hostedScale: CGFloat?

    var hostsAreStale: Bool {
        hostedContent !== content || hostedActions != chrome?.actions || hostedScale != chrome?.fontScale
    }

    var chromeViews: [NSView] {
        hosts.keys.sorted().compactMap { hosts[$0] }.flatMap { [$0.header, $0.footer] }
    }

    func apply(_ new: MarkdownText, to view: LinkTextView) {
        guard new !== content else { return }
        defer { content = new }
        guard let storage = view.textStorage else { return }
        if let old = content, old.isStreamingText, new.isStreamingText, old.style == new.style,
           let kept = old.keptPrefix(for: new.pieces) {
            let added = new.attributed.attributedSubstring(
                from: NSRange(location: kept.length, length: new.attributed.length - kept.length)
            )
            storage.replaceCharacters(
                in: NSRange(location: kept.length, length: storage.length - kept.length), with: added
            )
        } else {
            storage.setAttributedString(new.attributed)
        }
        view.needsLayout = true
        view.needsDisplay = true
    }

    func selectedText(in view: LinkTextView) -> String? {
        guard let content, let storage = view.textStorage else { return nil }
        return content.selectedText(in: storage, ranges: view.selectedRanges.map(\.rangeValue))
    }

    func placeChrome(in view: LinkTextView) {
        guard let content, let chrome, view.window != nil,
              let layout = view.layoutManager, let container = view.textContainer else { return }
        layout.ensureLayout(for: container)
        refreshHosts(content, chrome: chrome, in: view)
        let origin = view.textContainerOrigin
        for spec in content.code {
            guard let host = hosts[spec.index] else { continue }
            let frame = bounds(of: spec.block, range: spec.range, layout: layout).offsetBy(dx: origin.x, dy: origin.y)
            host.header.frame = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: MarkdownTextBlocks.codeHeader)
            let footer = max(spec.footer, 1)
            host.footer.frame = NSRect(x: frame.minX, y: frame.maxY - footer, width: frame.width, height: footer)
        }
    }

    private func refreshHosts(_ content: MarkdownText, chrome: Chrome, in view: LinkTextView) {
        guard hostsAreStale else { return }
        hostedContent = content
        hostedActions = chrome.actions
        hostedScale = chrome.fontScale
        for (index, host) in hosts where index >= content.code.count {
            host.header.removeFromSuperview()
            host.footer.removeFromSuperview()
            hosts[index] = nil
        }
        for spec in content.code {
            let host = hosts[spec.index] ?? {
                let made = (header: Self.makeHost(), footer: Self.makeHost())
                view.addSubview(made.header)
                view.addSubview(made.footer)
                hosts[spec.index] = made
                return made
            }()
            let command = CodeBlockCommand.runnable(code: spec.code, info: spec.info)
            let isExpanded = !spec.isFolded || spec.visibleAll
            host.header.rootView = AnyView(
                MarkdownCodeHeader(
                    code: spec.code, language: spec.language, command: command,
                    canRun: chrome.runsCommands && isExpanded, actions: chrome.actions
                )
                .environment(\.fontScale, chrome.fontScale)
                .environment(\.chatFont, chrome.chatFont)
            )
            let index = spec.index
            host.footer.rootView = AnyView(
                MarkdownCodeFooter(
                    lines: spec.lines, foldsLines: spec.isFolded, isExpanded: spec.visibleAll, command: command,
                    actions: chrome.actions,
                    onToggle: { chrome.onToggleFold(index) },
                    onHeight: { chrome.onFooterHeight(index, $0) }
                )
                .environment(\.fontScale, chrome.fontScale)
                .environment(\.chatFont, chrome.chatFont)
            )
        }
    }

    private static func makeHost() -> MarkdownChromeHost {
        let host = MarkdownChromeHost(rootView: AnyView(EmptyView()))
        host.safeAreaRegions = []
        host.sizingOptions = []
        return host
    }

    func drawBackdrops(in view: LinkTextView, dirty: NSRect) {
        guard let content, let layout = view.layoutManager, let container = view.textContainer else { return }
        let origin = view.textContainerOrigin
        for spec in content.code {
            let frame = bounds(of: spec.block, range: spec.range, layout: layout).offsetBy(dx: origin.x, dy: origin.y)
            guard frame.intersects(dirty) else { continue }
            let path = rounded(frame, radius: Metrics.corner)
            NSColor.controlBackgroundColor.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = Metrics.outline
            path.stroke()
        }
        for quote in content.quotes {
            let frame = bounds(of: quote.block, range: quote.range, layout: layout).offsetBy(dx: origin.x, dy: origin.y)
            guard frame.intersects(dirty) else { continue }
            NSColor.separatorColor.setFill()
            NSRect(x: frame.minX, y: frame.minY, width: TranscriptLayout.rule, height: frame.height).fill()
        }
        for table in content.tables {
            let first = bounds(of: table.first.block, range: NSRange(location: table.first.location, length: 0), layout: layout)
            let whole = first
                .union(bounds(of: table.last.block, range: NSRange(location: table.last.location, length: 0), layout: layout))
                .offsetBy(dx: origin.x, dy: origin.y)
            guard whole.intersects(dirty) else { continue }
            let head = first
                .union(bounds(of: table.firstRowLast.block, range: NSRange(location: table.firstRowLast.location, length: 0), layout: layout))
                .offsetBy(dx: origin.x, dy: origin.y)
            let path = rounded(whole, radius: Metrics.cornerSmall)
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            NSColor.controlBackgroundColor.setFill()
            head.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.separatorColor.setStroke()
            path.lineWidth = Metrics.outline
            path.stroke()
        }
        for rule in content.rules where rule.location < layout.numberOfGlyphs {
            let glyph = layout.glyphIndexForCharacter(at: rule.location)
            let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).offsetBy(dx: origin.x, dy: origin.y)
            guard line.intersects(dirty) else { continue }
            NSColor.separatorColor.setFill()
            NSRect(x: 0, y: line.midY, width: container.containerSize.width, height: Metrics.outline).fill()
        }
    }

    private func bounds(of block: NSTextBlock, range: NSRange, layout: NSLayoutManager) -> NSRect {
        guard let text = layout.textStorage?.string as NSString?, range.location <= text.length else { return .zero }
        let whole = text.paragraphRange(for: range)
        let glyphs = layout.glyphRange(forCharacterRange: whole, actualCharacterRange: nil)
        return layout.boundsRect(for: block, glyphRange: glyphs)
    }

    private func rounded(_ frame: NSRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(
            roundedRect: frame.insetBy(dx: Metrics.outline / 2, dy: Metrics.outline / 2),
            xRadius: radius, yRadius: radius
        )
    }
}
