import AppKit
import SwiftUI
import Core

@MainActor
enum ComposerInlineChipLayout {
    static let horizontalPadding: CGFloat = 5
    static let gap: CGFloat = 4
    static let cornerRadius: CGFloat = 4

    static func labelFont(for lineFont: NSFont) -> NSFont {
        NSFont.systemFont(ofSize: max(lineFont.pointSize - 1, 9))
    }

    static func iconSize(for lineFont: NSFont) -> CGFloat {
        min(ceil(labelFont(for: lineFont).pointSize), height(for: lineFont) - 3)
    }

    static func height(for lineFont: NSFont) -> CGFloat {
        floor(NSLayoutManager().defaultLineHeight(for: lineFont)) - 1
    }
}

enum InlineChip: Equatable, Sendable {
    case file(path: String)
    case instructions(InjectedInstruction)

    var label: String {
        switch self {
        case .file(let path): SentTurn.title(forFile: path) ?? (path as NSString).lastPathComponent
        case .instructions(let block): block.title
        }
    }

    var isInstructions: Bool {
        switch self {
        case .file(let path): SentTurn.title(forFile: path) != nil
        case .instructions: true
        }
    }

    var text: String {
        switch self {
        case .file(let path): AttachmentDraft.token(for: path)
        case .instructions(let block): block.body
        }
    }

    var path: String? {
        guard case .file(let path) = self else { return nil }
        return path
    }
}

@MainActor
enum ComposerChipText {
    static func subject(of storage: NSAttributedString, at index: Int) -> InlineChip? {
        guard index >= 0, index < storage.length else { return nil }
        let attachment = storage.attribute(.attachment, at: index, effectiveRange: nil)
        return (attachment as? InlineChipAttachment)?.subject
    }

    static func storage(
        for draft: String, paths: [String], font: NSFont, color: NSColor
    ) -> NSAttributedString {
        let parsed = AttachmentDraft.parse(draft, paths: paths)
        let result = NSMutableAttributedString()
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]

        for segment in parsed.segments {
            switch segment {
            case .text(let text):
                result.append(NSAttributedString(string: text, attributes: attributes))
            case .attachment(let path):
                result.append(chip(for: .file(path: path), font: font))
            }
        }
        return result
    }

    static func chip(
        for subject: InlineChip, font: NSFont, ground: AttachmentChipCell.Ground = .composer
    ) -> NSAttributedString {
        let attachment = InlineChipAttachment(subject: subject, font: font, ground: ground)
        attachment.attachmentCell = AttachmentChipCell(subject: subject, font: font, ground: ground)

        let chip = NSMutableAttributedString(attachment: attachment)
        chip.addAttributes([.font: font], range: NSRange(location: 0, length: chip.length))
        return chip
    }

    static func draft(of storage: NSAttributedString) -> String {
        var text = ""
        forEachRun(in: storage) { run in
            switch run {
            case .text(let string): text += string
            case .chip(let subject, _): text += subject.text
            }
        }
        return text
    }

    static func draft(of storage: NSAttributedString, in range: NSRange) -> String {
        draft(of: storage.attributedSubstring(from: range))
    }

    static func draftOffset(forStorage offset: Int, in storage: NSAttributedString) -> Int {
        var draft = 0
        var seen = 0
        forEachRun(in: storage) { run in
            switch run {
            case .text(let string):
                guard seen < offset else { return }
                let taken = min((string as NSString).length, offset - seen)
                draft += taken
                seen += taken
            case .chip(let subject, _):
                guard seen < offset else { return }
                draft += (subject.text as NSString).length
                seen += 1
            }
        }
        return draft
    }

    static func storageOffset(forDraft offset: Int, in storage: NSAttributedString) -> Int {
        var draft = 0
        var position = 0
        var answer: Int?

        forEachRun(in: storage) { run in
            guard answer == nil else { return }
            switch run {
            case .text(let string):
                let length = (string as NSString).length
                if draft + length >= offset {
                    answer = position + (offset - draft)
                } else {
                    draft += length
                    position += length
                }
            case .chip(let subject, _):
                let length = (subject.text as NSString).length
                guard draft + length < offset else {
                    answer = draft + length > offset && draft >= offset ? position : position + 1
                    return
                }
                draft += length
                position += 1
            }
        }
        return answer ?? position
    }

    enum Run {
        case text(String)
        case chip(InlineChip, at: Int)
    }

    static func forEachRun(in storage: NSAttributedString, _ body: (Run) -> Void) {
        let string = storage.string as NSString
        var pending = NSRange(location: 0, length: 0)

        func flush() {
            guard pending.length > 0 else { return }
            body(.text(string.substring(with: pending)))
            pending.length = 0
        }

        storage.enumerateAttribute(
            .attachment, in: NSRange(location: 0, length: storage.length)
        ) { value, range, _ in
            guard let subject = (value as? InlineChipAttachment)?.subject else {
                if pending.length == 0 { pending.location = range.location }
                pending.length += range.length
                return
            }
            flush()
            for offset in 0..<range.length {
                body(.chip(subject, at: range.location + offset))
            }
            pending.location = range.location + range.length
        }
        flush()
    }

    static func attachments(in storage: NSAttributedString) -> [(path: String, offset: Int)] {
        var found: [(String, Int)] = []
        forEachRun(in: storage) { run in
            guard case .chip(let subject, let offset) = run, let path = subject.path else { return }
            found.append((path, offset))
        }
        return found
    }
}

final class InlineChipAttachment: NSTextAttachment {
    let subject: InlineChip
    private let font: NSFont
    private let ground: AttachmentChipCell.Ground

    init(subject: InlineChip, font: NSFont, ground: AttachmentChipCell.Ground) {
        self.subject = subject
        self.font = font
        self.ground = ground
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? InlineChipAttachment else { return false }
        return other.subject == subject && other.font == font && other.ground == ground
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(subject.text)
        hasher.combine(font)
        return hasher.finalize()
    }
}

final class AttachmentChipCell: NSTextAttachmentCell {
    struct Ground: Equatable {
        var plate: NSColor
        var border: NSColor
        var ink: NSColor

        @MainActor static let composer = Ground(
            plate: NSColor(Palette.surfaceRaised), border: NSColor(Palette.border), ink: .labelColor
        )

        @MainActor static let userBubble = composer
    }

    let subject: InlineChip
    private let ground: Ground
    private let lineFont: NSFont

    private nonisolated let chipSize: NSSize
    private nonisolated let baselineOffset: NSPoint
    private nonisolated let iconSize: CGFloat
    private nonisolated let nameWidth: CGFloat

    private static let maxNameWidth: CGFloat = 170

    init(subject: InlineChip, font: NSFont, ground: Ground = .composer) {
        let nameFont = ComposerInlineChipLayout.labelFont(for: font)
        let name = subject.label
        let iconSize = ComposerInlineChipLayout.iconSize(for: font)
        let nameWidth = min(
            ceil((name as NSString).size(withAttributes: [.font: nameFont]).width),
            Self.maxNameWidth
        )
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let height = ComposerInlineChipLayout.height(for: font)

        self.subject = subject
        self.lineFont = font
        self.ground = ground
        self.iconSize = iconSize
        self.nameWidth = nameWidth
        self.chipSize = NSSize(
            width: ceil(
                ComposerInlineChipLayout.horizontalPadding * 2
                    + iconSize
                    + ComposerInlineChipLayout.gap
                    + nameWidth
            ),
            height: height
        )
        self.baselineOffset = NSPoint(x: 0, y: font.descender - (height - lineHeight) / 2)

        super.init(imageCell: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var label: String { subject.label }

    private var nameAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        return [
            .font: ComposerInlineChipLayout.labelFont(for: lineFont),
            .foregroundColor: ground.ink,
            .paragraphStyle: paragraph,
        ]
    }

    override func cellSize() -> NSSize { chipSize }

    override func cellBaselineOffset() -> NSPoint { baselineOffset }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        draw(withFrame: cellFrame, in: controlView, characterIndex: NSNotFound)
    }

    override func draw(
        withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex: Int
    ) {
        let frame = cellFrame.insetBy(dx: 0, dy: 0.5)
        let plate = NSBezierPath(
            roundedRect: frame,
            xRadius: ComposerInlineChipLayout.cornerRadius,
            yRadius: ComposerInlineChipLayout.cornerRadius
        )

        ground.plate.setFill()
        plate.fill()
        ground.border.setStroke()
        plate.lineWidth = 1
        plate.stroke()

        let side = iconSize
        let iconRect = NSRect(
            x: frame.minX + ComposerInlineChipLayout.horizontalPadding,
            y: frame.midY - side / 2,
            width: side,
            height: side
        )
        let hoverFraction = (controlView as? ComposerTextView)?
            .chipHoverFraction(at: characterIndex) ?? 0
        icon?.draw(
            in: iconRect, from: .zero, operation: .sourceOver, fraction: 1 - hoverFraction,
            respectFlipped: true, hints: nil
        )
        if hoverFraction > 0 {
            close?.draw(
                in: iconRect, from: .zero, operation: .sourceOver, fraction: hoverFraction,
                respectFlipped: true, hints: nil
            )
        }

        let name = NSAttributedString(string: label, attributes: nameAttributes)
        let height = name.size().height
        let nameRect = NSRect(
            x: iconRect.maxX + ComposerInlineChipLayout.gap,
            y: frame.midY - height / 2,
            width: nameWidth,
            height: height
        )
        name.draw(with: nameRect, options: [.usesLineFragmentOrigin])
    }

    private var icon: NSImage? {
        if case .file(let path) = subject, !subject.isInstructions {
            return FileTypeIcon.icon(for: (path as NSString).lastPathComponent)
        }
        let size = NSImage.SymbolConfiguration(pointSize: iconSize - 3, weight: .regular)
        let colour = NSImage.SymbolConfiguration(paletteColors: [ground.ink])
        return NSImage(systemSymbolName: "doc.text", accessibilityDescription: label)?
            .withSymbolConfiguration(size.applying(colour))
    }

    private func isRemovable(from controlView: NSView?, at characterIndex: Int) -> Bool {
        guard let composer = controlView as? ComposerTextView else { return false }
        return composer.isChipHovered(at: characterIndex)
    }

    private var close: NSImage? {
        ChipRemoveImage.of(
            diameter: iconSize,
            ink: ground.ink,
            plate: NSColor(Palette.surface),
            border: ground.border,
            label: "Remove \(label)"
        )
    }

    private func closeRect(in frame: NSRect) -> NSRect {
        NSRect(
            x: frame.minX,
            y: frame.minY,
            width: ComposerInlineChipLayout.horizontalPadding
                + iconSize
                + ComposerInlineChipLayout.gap / 2,
            height: frame.height
        )
    }

    override func wantsToTrackMouse() -> Bool { true }

    override func trackMouse(
        with event: NSEvent,
        in cellFrame: NSRect,
        of controlView: NSView?,
        atCharacterIndex charIndex: Int,
        untilMouseUp flag: Bool
    ) -> Bool {
        guard event.clickCount >= 1, let composer = controlView as? ComposerTextView,
              let path = subject.path
        else { return false }
        if isRemovable(from: controlView, at: charIndex),
           closeRect(in: cellFrame).contains(composer.convert(event.locationInWindow, from: nil)) {
            composer.removeAttachment(at: charIndex)
            return true
        }
        composer.openAttachment?(path)
        return true
    }
}
