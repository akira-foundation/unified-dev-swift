import AppKit

final class LineNumberRuler: NSRulerView {
    private static let padding: CGFloat = 6

    private var lineStarts: [Int] = [0]
    private var isStale = true

    var fill: NSColor = .textBackgroundColor
    var numberColor: NSColor = .tertiaryLabelColor {
        didSet { attributes[.foregroundColor] = numberColor }
    }

    private var attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(
            ofSize: max(9, CodeMetrics.font.pointSize - 1), weight: .regular
        ),
        .foregroundColor: NSColor.tertiaryLabelColor,
    ]

    init(scrollView: NSScrollView, textView: NSTextView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
        clipsToBounds = true

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipViewDidResize),
            name: NSView.frameDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func clipViewDidScroll() {
        needsDisplay = true
    }

    @objc private func clipViewDidResize() {
        alignTextToGutter()
        needsDisplay = true
    }

    override func viewWillDraw() {
        alignTextToGutter()
        super.viewWillDraw()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("not used") }

    func refresh() {
        isStale = true
        if let textView = clientView as? NSTextView {
            rebuildIfNeeded(textView.string as NSString)
            fitThickness()
        }
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer
        else { return }

        let text = textView.string as NSString
        rebuildIfNeeded(text)

        let gutter = bounds
        fill.setFill()
        gutter.fill()

        let inset = textView.textContainerInset.height
        let origin = convert(NSPoint.zero, from: textView).y + inset

        let visible = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let firstCharacter = layoutManager
            .characterRange(forGlyphRange: visible, actualGlyphRange: nil)
            .location
        var index = line(containing: firstCharacter)

        while index < lineStarts.count {
            let start = lineStarts[index]
            guard start <= text.length else { break }

            guard let fragment = fragment(for: start, in: text, layoutManager: layoutManager)
            else { break }
            let y = origin + fragment.minY
            if y > rect.maxY { break }

            if y + fragment.height >= rect.minY {
                let label = "\(index + 1)" as NSString
                let size = label.size(withAttributes: attributes)
                label.draw(
                    at: NSPoint(
                        x: ruleThickness - size.width - Self.padding,
                        y: y + (fragment.height - size.height) / 2
                    ),
                    withAttributes: attributes
                )
            }
            index += 1
        }
    }

    private func fragment(
        for start: Int, in text: NSString, layoutManager: NSLayoutManager
    ) -> NSRect? {
        guard start == text.length else {
            let glyph = layoutManager.glyphIndexForCharacter(at: start)
            return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        guard layoutManager.extraLineFragmentTextContainer != nil else {
            return start == 0 ? NSRect(x: 0, y: 0, width: 0, height: CodeMetrics.rowHeight) : nil
        }
        return layoutManager.extraLineFragmentRect
    }

    private func rebuildIfNeeded(_ text: NSString) {
        guard isStale else { return }
        isStale = false

        var starts: [Int] = [0]
        var index = 0
        while index < text.length {
            if text.character(at: index) == 10 { starts.append(index + 1) }
            index += 1
        }
        lineStarts = starts
    }

    private func line(containing offset: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if lineStarts[middle] <= offset { low = middle } else { high = middle - 1 }
        }
        return low
    }

    private func alignTextToGutter() {
        guard let textView = clientView as? NSTextView else { return }
        let reserved = scrollView.map { $0.contentView.convert($0.contentView.bounds.origin, to: $0).x } ?? 0
        let remaining = max(0, ruleThickness - reserved)
        let inset = NSSize(
            width: remaining + CodeMetrics.textInset, height: textView.textContainerInset.height
        )
        guard textView.textContainerInset != inset else { return }
        textView.textContainerInset = inset
    }

    private func fitThickness() {
        let digits = max(2, String(lineStarts.count).count)
        let sample = String(repeating: "0", count: digits) as NSString
        let width = ceil(sample.size(withAttributes: attributes).width) + Self.padding * 2
        if abs(width - ruleThickness) > 0.5 {
            ruleThickness = width
            scrollView?.tile()
        }
        alignTextToGutter()
    }
}
