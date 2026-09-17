import AppKit

@MainActor
final class TranscriptTableView: NSTableView {
    var didChangeWidth: (@MainActor () -> Void)?

    private var isAligningRows = false
    private var alignmentWork: Task<Void, Never>?
    private var laidOutWidth: CGFloat = 0

    override func setFrameSize(_ newSize: NSSize) {
        let widthMoved = newSize.width != frame.width
        super.setFrameSize(newSize)
        if widthMoved { needsLayout = true }
    }

    override func layout() {
        super.layout()
        if bounds.width != laidOutWidth {
            laidOutWidth = bounds.width
            didChangeWidth?()
        }
        alignRowOrigins()
    }

    func alignRowOrigins() {
        guard !isAligningRows, alignmentWork == nil else { return }
        isAligningRows = true
        defer { isAligningRows = false }
        enumerateAvailableRowViews { row, index in
            guard index >= 0, index < self.numberOfRows else { return }
            let target = self.rect(ofRow: index).minY
            if abs(row.frame.minY - target) > 0.5 {
                row.setFrameOrigin(NSPoint(x: row.frame.minX, y: target))
            }
        }
    }

    func deferRowAlignment(for seconds: Double) {
        guard seconds > 0 else { return }
        alignmentWork?.cancel()
        alignmentWork = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            alignmentWork = nil
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }
}
