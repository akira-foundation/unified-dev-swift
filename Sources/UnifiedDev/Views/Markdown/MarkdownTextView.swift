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
    private var signatures: [Int: HostSignature] = [:]
    private var frames: Frames?

    private struct HostSignature: Equatable {
        var code: String
        var info: String
        var isFolded: Bool
        var visibleAll: Bool
        var lines: Int
        var actions: TranscriptLinkActions
        var scale: CGFloat
        var face: ChatFont
        var runsCommands: Bool
    }

    private struct Frames {
        var content: MarkdownText
        var width: CGFloat
        var code: [NSRect]
        var quotes: [NSRect]
        var tables: [(whole: NSRect, head: NSRect)]
    }
    private var hostedContent: MarkdownText?
    private var hostedActions: TranscriptLinkActions?
    private var hostedScale: CGFloat?
    private var hostedRuns: Bool?
    private var hostedFace: ChatFont?

    var hostsAreStale: Bool {
        hostedContent !== content || hostedActions != chrome?.actions || hostedScale != chrome?.fontScale || hostedFace != chrome?.chatFont || hostedRuns != chrome?.runsCommands
    }

    var chromeViews: [NSView] {
        hosts.keys.sorted().compactMap { hosts[$0] }.flatMap { [$0.header, $0.footer] }
    }

    func pointer(at point: NSPoint) -> TranscriptPointer? {
        let bars = hosts.values.lazy.flatMap { [$0.header, $0.footer] }
        guard let host = bars.first(where: { $0.frame.contains(point) }) else { return nil }
        return .overChrome(selectableText: host.selectableText.contains(host.convert(point, from: host.superview)))
    }

    func apply(_ new: MarkdownText, to view: LinkTextView) {
        guard new !== content else { return }
        defer { content = new }
        guard let storage = view.textStorage else { return }
        let selected = view.selectedRanges.map(\.rangeValue)
        let held = selected.map { (storage.string as NSString).substring(with: $0) }
        if let old = content, new.source === old {
            let added = new.attributed.attributedSubstring(
                from: NSRange(location: new.keptLength, length: new.attributed.length - new.keptLength)
            )
            storage.replaceCharacters(
                in: NSRange(location: new.keptLength, length: storage.length - new.keptLength), with: added
            )
        } else {
            storage.setAttributedString(new.attributed)
        }
        Self.restore(selected, holding: held, in: view, storage: storage)
        view.needsLayout = true
        view.needsDisplay = true
    }

    private static func restore(_ selected: [NSRange], holding held: [String], in view: LinkTextView, storage: NSTextStorage) {
        let string = storage.string as NSString
        guard selected.contains(where: { $0.length > 0 }),
              zip(selected, held).allSatisfy({ NSMaxRange($0) <= string.length && string.substring(with: $0) == $1 })
        else { return }
        view.selectedRanges = selected.map { NSValue(range: $0) }
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
        let measured = measuredFrames(of: content, in: view, layout: layout)
        for (spec, frame) in zip(content.code, measured.code) {
            guard let host = hosts[spec.index] else { continue }
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
        hostedRuns = chrome.runsCommands
        hostedFace = chrome.chatFont
        for (index, host) in hosts where index >= content.code.count {
            host.header.removeFromSuperview()
            host.footer.removeFromSuperview()
            hosts[index] = nil
            signatures[index] = nil
        }
        for spec in content.code {
            let host = hosts[spec.index] ?? {
                let made = (header: Self.makeHost(), footer: Self.makeHost())
                view.addSubview(made.header)
                view.addSubview(made.footer)
                hosts[spec.index] = made
                return made
            }()
            let signature = HostSignature(
                code: spec.code, info: spec.info, isFolded: spec.isFolded, visibleAll: spec.visibleAll,
                lines: spec.lines, actions: chrome.actions, scale: chrome.fontScale, face: chrome.chatFont, runsCommands: chrome.runsCommands
            )
            guard signatures[spec.index] != signature else { continue }
            signatures[spec.index] = signature
            let command = CodeBlockCommand.runnable(code: spec.code, info: spec.info)
            let isExpanded = !spec.isFolded || spec.visibleAll
            host.header.rootView = AnyView(
                MarkdownCodeHeader(
                    code: spec.code, language: spec.language, command: command,
                    canRun: chrome.runsCommands && isExpanded, actions: chrome.actions,
                    onControls: { [weak header = host.header] in header?.controls = $0 }
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
                    onHeight: { chrome.onFooterHeight(index, $0) },
                    onControls: { [weak footer = host.footer] in footer?.controls = $0 },
                    onOutput: { [weak footer = host.footer] in footer?.selectableText = $0 }
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

    private func measuredFrames(of content: MarkdownText, in view: LinkTextView, layout: NSLayoutManager) -> Frames {
        let width = view.textContainer?.containerSize.width ?? 0
        if let frames, frames.content === content, frames.width == width { return frames }
        let origin = view.textContainerOrigin
        func frame(_ block: NSTextBlock, _ location: Int, _ length: Int = 0) -> NSRect {
            bounds(of: block, range: NSRange(location: location, length: length), layout: layout)
                .offsetBy(dx: origin.x, dy: origin.y)
        }
        let measured = Frames(
            content: content,
            width: width,
            code: content.code.map { frame($0.block, $0.range.location, $0.range.length) },
            quotes: content.quotes.map { frame($0.block, $0.range.location, $0.range.length) },
            tables: content.tables.map { table in
                let first = frame(table.first.block, table.first.location)
                return (
                    whole: first.union(frame(table.last.block, table.last.location)),
                    head: first.union(frame(table.firstRowLast.block, table.firstRowLast.location))
                )
            }
        )
        frames = measured
        return measured
    }

    func drawBackdrops(in view: LinkTextView, dirty: NSRect) {
        guard let content, let layout = view.layoutManager, let container = view.textContainer else { return }
        let origin = view.textContainerOrigin
        let measured = measuredFrames(of: content, in: view, layout: layout)
        for frame in measured.code where frame.intersects(dirty) {
            let path = rounded(frame, radius: Metrics.corner)
            NSColor.controlBackgroundColor.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = Metrics.outline
            path.stroke()
        }
        for frame in measured.quotes where frame.intersects(dirty) {
            NSColor.separatorColor.setFill()
            NSRect(x: frame.minX, y: frame.minY, width: TranscriptLayout.rule, height: frame.height).fill()
        }
        for table in measured.tables where table.whole.intersects(dirty) {
            let path = rounded(table.whole, radius: Metrics.cornerSmall)
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            NSColor.controlBackgroundColor.setFill()
            table.head.fill()
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
